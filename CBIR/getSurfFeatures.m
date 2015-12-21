
%% params
 useBarcode = false;

%% load all IRMA training and testing images:
trainPath = '../../IRMA/2009/Training Data/ImageCLEFmed2009_train.02/';
path = sprintf('%s*.png', trainPath);
files = dir(path);

%sanitize to remove images named "blah - Copy.png":
i=1;
for file = files'
   if regexp(file.name, 'Copy')
      files(i) = []; 
      fprintf('deleted %s\n', file.name);
   else
       i = i+1;
   end
end

testPath = '../../IRMA/2009/Testing Data/';
path = sprintf('%s*.png', testPath);
testFiles = dir(path);

%append all test files to the list of training files, keeping track of the 
%end of the training files to distinguish them later:
trainingLength = length(files);
files = vertcat(files, testFiles);
testingLength = length(files) - trainingLength;
%%
i=1;
for file = files'
   %add path for either training or testing folder, depending on file:
   if (i <= trainingLength)
       imgpath = sprintf('%s/%s', trainPath, file.name);
   else
       imgpath = sprintf('%s/%s', testPath, file.name);
   end
   irma{i} = imread(imgpath);
   
   %any 3-channel images seem to be the same for all colour channels, so we
   %can just remove all but channel 1:
   if (length(irma{i}(1,1,:)) == 3)
       irma{i}(:,:,2:3) = [];
   end
   %TODO: filter the 3-channel greyscale images to 1-channel, and make sure
    %nothing is actually colour, or we'll need to handle that differently
   
   i = i+1;
   %print progress every 100 images (mod is cheaper than a print)...
   if mod(i,100) ==0
       i
   end
end
%%
save('trainingTestingFiles.mat', 'irma', '-v7.3'); %must use recent version since large variable
save('trainingTestingLengths.mat', 'trainingLength', 'testingLength');
save('files.mat', 'files');

%% if we want to use preloaded files instead:
load('trainingTestingFiles.mat', 'irma');
load('trainingTestingLengths.mat', 'trainingLength', 'testingLength');
load('files.mat');

%% calculate SURF features for them (using a low enough threshold to guarantee a min number of features to use)
numSURF=10;
features = cell(1, length(files));
strongestfeatures = cell(1, length(files));
fprintf('Progress:\n');
fprintf(['\n' repmat('.',1,(floor(length(files)/100))) '\n\n']);

for i=1:length(files) %changed so not a parfor -- disk access is the delimiting factor, not cpu
   SURFfeatures{i} = detectSURFFeatures(irma{i}, 'MetricThreshold', 200);
   strongestSURFfeatures{i}=SURFfeatures{i}.selectStrongest(numSURF);

   %fprintf('Calculating features for %d \n', i);
   if mod(i,100) == 0
   fprintf('\b|\n');
   end
end
% so we don't have to do this over again unless absolutely necessary:
save('strongestSURFfeatures.mat', 'strongestSURFfeatures');

%% if we want to use precalculated SURF features:
load('strongestSURFfeatures.mat', 'strongestSURFfeatures');

%%
%load csv with irma code for each image, then match up with what class that is:
%workaround to avoid strange readtable/etc bug -- saved as a mat
load('irmaCSV.mat')
load('irmaCSVtest.mat')

%%
saveSURFtoFile('training.txt', strongestSURFfeatures(1:trainingLength), 10, irmaCSV(:,3));
saveSURFtoFile('testing.txt', strongestSURFfeatures(trainingLength+1:end), 10, irmaCSVtest(:,3));

%save subsections:
for i=1:4
    trainPath = sprintf('training_sub%d.txt', i);
    testPath = sprintf('testing_sub%d.txt', i);
    saveSURFtoFile(trainPath, strongestSURFfeatures(1:trainingLength), 0, irmaCSV(:,i+3));
    saveSURFtoFile(testPath, strongestSURFfeatures(trainingLength+1:end), 0, irmaCSVtest(:,i+3));
end

%% calculate radon barcodes (RBCs) for each image 
addpath('../');
barcode = [];
barcodeDimX = 64;
barcodeDimY = 64;
barcodeNumProj = 32;
%i=1;
for i=1:length(irma)%file = files'
    barcode(i,:) = extractRBC(irma{i}, barcodeDimX, barcodeDimY, barcodeNumProj, false);%32, 32, 8, false);
    %fprintf('Extracting barcodes for image %d \r', i); 
end
save(sprintf('barcodes_%d_%d_%d.mat', barcodeDimX, barcodeDimY, barcodeNumProj), 'barcode');

%%


%% use barcode-only Hamming distance error metric:
curr = 1;
for i=trainingLength + 1:trainingLength + testingLength
    %find closest barcode from all training images to each testing image:
    barcodeMatch(curr) = 1;
    closestDistance = pdist2(barcode(i,:),barcode(1,:),'hamming');
    for j=2:trainingLength
    	currDist = pdist2(barcode(i,:),barcode(j,:),'hamming');
        if (currDist < closestDistance)
            closestDistance = currDist;
            barcodeMatch(curr) = j;
        end
    end
    curr = curr + 1;
end
%%
% save just barcodes for svm:
trainingfile = fopen('training_barcodes.txt', 'w');
testingfile = fopen('testing_barcodes.txt', 'w');

%for i=1:trainingLength
    csvwrite('training_barcodes.txt', horzcat(cell2mat(irmaCSV(:,3)), barcode(1:trainingLength, :)));
    csvwrite('testing_barcodes.txt', horzcat(cell2mat(irmaCSVtest(:,3)), barcode(trainingLength+1:end, :)));
%fprintf(trainingFile, "%strongestSURFfeatures(1:trainingLength), 10, irmaCSV(:,3));
%end
%saveSURFtoFile('testing_barcodes.txt', strongestSURFfeatures(trainingLength+1:end), 10, irmaCSVtest(:,3));

%% saving SURF, etc features from training images to array for input to lsh
n=1;
inputFeat = [];
for i =1:trainingLength
    currCount = strongestSURFfeatures{i}.Count;
    
    %lookup table to keep track of which features belong to which image 
    featInd(n:n+currCount) = i;
    
    for j=1:currCount
        
        currFeat=strongestSURFfeatures{i}(j);
        
%         if (useBarcode)
%             currSurf=[double(currFeat.Scale); double(currFeat.SignOfLaplacian);...
%                 double(currFeat.Orientation); double(currFeat.Location(1));...
%                 double(currFeat.Location(2)); double(currFeat.Metric)] ;
%             inputFeat(:,n) = vertcat(currSurf, barcode{i}');
%         else
%              inputFeat(:,n) = [double(currFeat.Scale); double(currFeat.SignOfLaplacian);...
%                 double(currFeat.Orientation); double(currFeat.Location(1));...
%                 double(currFeat.Location(2)); double(currFeat.Metric)];
%         end
            inputFeat(:,n) = extractFeatures(irma{i}, currFeat);
        n=n+1;
    end
end
save('featInd.mat', 'featInd');

%% saving SURF, etc features from testing images to array 
n=1;
testFeat = [];
testFeatInd = [];
for i = trainingLength+1:testingLength+trainingLength
    
    currCount = strongestSURFfeatures{i}.Count;
    
    %lookup table to keep track of which features belong to which image 
    testFeatInd(n:n+currCount) = i;

    for j=1:currCount        
        currFeat=strongestSURFfeatures{i}(j);
        
%         if (useBarcode)
%             currSurf=[double(currFeat.Scale); double(currFeat.SignOfLaplacian);...
%                 double(currFeat.Orientation); double(currFeat.Location(1));...
%                 double(currFeat.Location(2)); double(currFeat.Metric)] ;
%             testFeat(:,n) = vertcat(currSurf, barcode{i}');
%         else
%             testFeat(:,n)=[double(currFeat.Scale); double(currFeat.SignOfLaplacian);...
%                 double(currFeat.Orientation); double(currFeat.Location(1));...
%                 double(currFeat.Location(2)); double(currFeat.Metric)] ;
%         end
        testFeat(:,n) = extractFeatures(irma{i}, currFeat);
        n=n+1;
    end
end
save('testFeatInd.mat', 'testFeatInd');

%%
load('featInd.mat');
load('testFeatInd.mat');

%% save proper 64-bit SURF features for SVM:

trainingfile = fopen('training_propersurf.txt', 'w');
testingfile = fopen('testing_propersurf.txt', 'w');

%for i=1:trainingLength
    csvwrite('training_propersurf.txt', horzcat(cell2mat(irmaCSV(:,3)), inputFeat'));
    csvwrite('testing_propersurf.txt', horzcat(cell2mat(irmaCSVtest(:,3)), testFeat'));

%% save proper 64-bit SURF features for SVM:
n=1;
currFeat = [];
trainingfile = 'training_propersurf.txt';
fopen(trainingfile, 'w');
for i =1:trainingLength
    currCount = strongestSURFfeatures{i}.Count;
    
    %lookup table to keep track of which features belong to which image 
    featInd(n:n+currCount) = i;
    
    for j=1:currCount
        
        currFeat(n) = cell2mat(irmaCSV(i,3)); %, inputFeat(:,n)');
        n=n+1;
    end
end
csvwrite(trainingfile, horzcat(currFeat', inputFeat'));
%%
n=1;
currFeat = [];
testingfile = 'testing_propersurf.txt';
fopen(testingfile, 'w');
for i = trainingLength + 1:trainingLength + testingLength
    currCount = strongestSURFfeatures{i}.Count;
    
    %lookup table to keep track of which features belong to which image 
    testFeatInd(n:n+currCount) = i;
    
    for j=1:currCount
        
        currFeat(n) = cell2mat(irmaCSVtest(i-trainingLength,3));
        n=n+1;
    end
end
csvwrite(testingfile, horzcat(currFeat', testFeat'));


%% do matching with FLANN instead of LSH:
%for i=1:
%extractFeatures(



%% creating lsh data structure for input features, and then save it:
addpath('../lshcode');
Te=lsh('e2lsh', 50,20,size(inputFeat,1), inputFeat, 'range', 255, 'w', -4);

save('lshtable_surfvec.mat', 'Te');

%% or load previous table:
load('lshtable_surfvec.mat');

%% Find lsh matches and their consensus:
tic
rNN=50; %number of desired matches for lsh
bestMatch = zeros(testingLength, 1);
saveToOutput = zeros(testingLength, 1);
best=[];
byFeature = false;
useWeights = true;
justBarcodesAfter = true;

%go through every test image:
currTestFeat = 1;
threshold = 0;%2;    %3;
j=1;
overallFeatTally = [];

iNNListTest = {};
parfor i=1:length(inputFeat)
   [iNNListTest{i},~]=lshlookup(inputFeat(:,i),inputFeat,Te,'k',rNN); 
end
%%
for currImg = (trainingLength + 1):(trainingLength + testingLength)
    %do lsh on every feature of the current image, and keep a tally:
    tally = [];
    featTally=[featInd' zeros(length(featInd),1)];
   
    
    while (testFeatInd(currTestFeat) == currImg) && (currTestFeat <= length(testFeat))
        %iNN = indecides of matches, numcand = number of examined
        %candidates in the lookup table 
        iNN = iNNListTest{currTestFeat};
        
        weight = 1;
        %add all hits for this feature to the tally for the current image:
        for i=1:length(iNN)
            %find what image number this feature is from:
            hitImg = featInd(iNN(i));
            
            if isempty(tally)
                %this is the first feature in the tally:
                tally(1, 1:2)=[hitImg weight];
            else
                %check to see if we've already found this feature's image:
                index=find(hitImg == tally(:,1));
                if ~isempty(index)
                    %we've found this image before, so increment tally:
                    tally(index,2)=tally(index,2)+weight;
                else
                    %new image, so add a spot for it with a count of 1:
                    tally(end+1,:)=[hitImg weight];
                end
            end
            if (useWeights && weight > 0.1)
                weight = weight -0.05; %* 0.9;
            end
        end
        
        if (byFeature)
            %keeping a tally of the features LSH hit with currTestFeat
            for j=1:length(iNN)
                %go through nearest neighbor features returned and update tally for each 
                featTally(iNN(j),2)=featTally(iNN(j),2)+weight;
            end
        end
        
        currTestFeat = currTestFeat + 1;
    end
    
    %now we've done all features of the current image, so check the
    %consensus:
    if isempty(tally)
        fprintf('Nothing found! :( %d lengthINN = %d\n', currImg, length(iNN));
        bestMatch(currImg - trainingLength) = 0;
    else
        sum(tally(:,2)>1);
        best = sortrows(tally, -2);
        bestMatch(currImg - trainingLength) = best(1,1);
        
    end
    
    if justBarcodesAfter
        % we just want to save the top matches to a list to check barcodes
        % later
    
    else
        %store test images ids with consensus below a threshold in a separate array
        if best(1,2)<threshold
            if (byFeature)
                overallFeatTally{end+1, 1} = currImg;
                overallFeatTally{end, 2} = featTally;
            else
                %make sparse representation of *image* hits...
                sparseTally = zeros(trainingLength, 1);
                if (~isempty(tally))
                    sparseTally(tally(:,1)) = tally(:,2);
                end
                overallFeatTally{end+1, 1} = currImg;
                overallFeatTally{end, 2} = sparseTally;
                %fprintf('added!');
            end
        else
            %our lsh result is good enough, so mark it to save to an output!
            saveToOutput(currImg - trainingLength) = 1;
        end
    end
end


%% output results to files so that we can check the official IRMA error:

%TODO: if no match was found, we have a 0 -- for now, we'll pretend
%itjames 's a random image to make things work out:
bestMatch(bestMatch == 0) = 1;

%convert training, testing indices to actual image ids:
realImageIDs = zeros(trainingLength + testingLength, 1);
i=1;
for file = files'
    %remove file extension and get the image number from filename:
    realImageIDs(i) = str2double(regexprep(file.name, '.png', ''));
    if isnan(realImageIDs(i) )
        fprintf('%s isnan!!!\n', file.name);
    end
    i=i+1;
end
%%
%since we can't do == on a cell array...
tempCSV = cell2mat(irmaCSV(:,1));

fileID = fopen('outputfixed.txt', 'w');
for i=1:testingLength
    %check if there was a consensus -- otherwise the SVM will be doing it instead:
    %if (saveToOutput(i))
        %now look up the real ID of each test image:
        currID = realImageIDs(i+trainingLength);
        %and also that of its best match, and use that to retrieve its IRMA code:
        matchID = realImageIDs(bestMatch(i));
        matchIRMA = irmaCSV(tempCSV == matchID, 2);

        fprintf(fileID, '%d %s\n', currID, matchIRMA{1});
    %end
end

toc
%% saving images with bad consensus to file for input to svm
% tempCSVtest=cell2mat(irmaCSVtest(:,1));
% for i=1:length(svmInput)
%     svmFeat(i)=strongestSURFfeatures(svmInput(i));
%     svmIRMAClass(i)=irmaCSVtest(find(realImageIDs(svmInput(i))== tempCSVtest(:,1)), 3)
% end
% 
% saveSURFtoFile('svmInput.txt', svmFeat, 0, svmIRMAClass);

%% appending svm output file to lsh output file 

system('cat outputbof.txt svmoutputbof_sub.txt > output_bofmerged.txt');


%% saving BoF-style tally for all images with bad consensus to file for SVM input:
tempCSVtest=cell2mat(irmaCSVtest(:,1));

outpath = 'testingbof_10.txt';

%fileID = fopen('output_weighted2.txt', 'w');
bofRealIds = realImageIDs(cell2mat(overallFeatTally(:,1)));
fopen(outpath, 'w');
%dlmwrite('output_weighted2.txt', horzcat(bofRealIds, overallFeatTally{:,2}(:,2)
for i=1:length(overallFeatTally)
    svmIRMAClass = irmaCSVtest(find(bofRealIds(i)== tempCSVtest(:,1)), 3);
    if (byFeature)
        bofToWrite = horzcat(svmIRMAClass, overallFeatTally{i,2}(:,2)');
    else
        bofToWrite = horzcat(svmIRMAClass, overallFeatTally{i,2}(:,1)');
    end
    dlmwrite(outpath, bofToWrite, '-append');
end
%dlmwrite('testingbof.txt', bofToWrite, ' ');


%% Save SVM training data -- hit frequency for all training images on lsh table
tic
outpath = 'trainingbof_10.txt'
fopen(outpath, 'w');
byFeature = false;

bofToWrite = [];
%go through every training image:

overallTrainingTally = [];
useWeights = 1;

iNNList = {};
parfor i=1:length(inputFeat)
   [iNNList{i},~]=lshlookup(inputFeat(:,i),inputFeat,Te,'k',rNN); 
end
%%
currTestFeat = 1;
j=1;
tempCSV = cell2mat(irmaCSV(:,1));
for currImg = 1:trainingLength
    if (byFeature)
        %do lsh on every feature of the current image, and keep a tally:
        featTally = zeros(length(featInd),1); 
    else
        %do lsh on every feature of the current image, and keep a tally of
        %which *images* it hit:
        featTally = zeros(trainingLength,1); 
    end
    
    while (featInd(currTestFeat) == currImg) && (currTestFeat <= length(inputFeat))
        %iNN = indecides of matches, numcand = number of examined
        %candidates in the lookup table 
        %[iNN,numcand]=lshlookup(inputFeat(:,currTestFeat),inputFeat,Te,'k',rNN);
        iNN = iNNList{currTestFeat};
        
        weight = 1;
        %keeping a tally of the features LSH hit with currTestFeat
        for j=1:length(iNN)            
            if (byFeature)
                %go through nearest neighbor features returned and update tally for each 
                featTally(iNN(j))=featTally(iNN(j))+weight;
            else
                %we want to group by image, for quick-and-dirty dimensionality
                %reduction:
                hitImg = featInd(iNN(j));
                featTally(hitImg)=featTally(hitImg)+weight;
            end
            if (useWeights && weight > 0.1)
                weight = weight -0.05; %* 0.9;
            end
        end
        %fprintf('actually run!')
        %lengthinn = length(iNN)
        currTestFeat = currTestFeat + 1;
    end
%lengthinn = length(iNN)
    
    svmIRMAClass = irmaCSV(find(realImageIDs(currImg)== tempCSV(:,1)), 3);


    %bofToWrite(currImg,:) = horzcat(realImageIDs(i), featTally');
    bofToWrite = horzcat(svmIRMAClass, featTally');
    %max(featTally)
    dlmwrite(outpath, bofToWrite, '-append');
    
end
toc
tic
%save('trainingbof.mat', 'bofToWrite');
toc
%% was for saving the ground truth to a form the python error script can read:
% fileID = fopen('outputIRMAtestclasses.txt', 'w');
% for i=1:1733
%     fprintf(fileID, '%d %s\n', ImageCLEFmed2009testcodes{i,1}, ImageCLEFmed2009testcodes{i,2});
% end


%% try bag-of-words:

for i=1:trainingLength
    trainingFilepaths{i} = sprintf('%s%s', trainPath, files(i).name);
end
trainingImageSet = imageSet(trainingFilepaths);
%%
tic
extractorFcn = @bagOfFeaturesExtractor;
bag = bagOfFeatures(trainingImageSet, 'CustomExtractor',extractorFcn, 'VocabularySize', 20000);
save('bag_better.mat', 'bag');
toc
%% generate training vector of SURF features for SVM with the bag:
tic
for i=1:trainingLength
    currImg = read(trainingImageSet(1),i);
    trainingFeatureVector(i,:) = encode(bag, currImg);
end
toc

%% %% generate testing vector of SURF features for SVM with the bag:
tic

for i=1:testingLength
    testingFilepaths{i} = sprintf('%s%s', testPath, files(i+trainingLength).name);
end
testingImageSet = imageSet(testingFilepaths);
for i=1:testingLength
    currImg = read(testingImageSet(1),i);
    testingFeatureVector(i,:) = encode(bag, currImg);
end
toc
%% save everything to text files for reading into the SVM:
%trainingfile = fopen('training_properbof.txt', 'w');
%testingfile = fopen('testing_properbof.txt', 'w');

csvwrite('training_properbof.txt', horzcat(cell2mat(irmaCSV(:,3)), trainingFeatureVector));
csvwrite('testing_properbof.txt', horzcat(cell2mat(irmaCSVtest(:,3)), testingFeatureVector));
