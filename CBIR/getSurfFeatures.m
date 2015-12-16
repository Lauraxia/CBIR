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

%% if we want to use preloaded files instead:
load('trainingTestingFiles.mat', 'irma');
load('trainingTestingLengths.mat', 'trainingLength', 'testingLength');

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

%% calculate radon barcodes (RBCs) for each image 
addpath('../');
i=1;
for file = files'
    barcode{i} = extractRBC(irma{i}, 32, 32, 8, false);
    fprintf('Extracting barcodes for image %d \r', i); 
    i=i+1;
end



%% saving SURF features from training images to array for input to lsh
n=1;

for i =1:trainingLength
    currCount = strongestSURFfeatures{i}.Count;
    
    %lookup table to keep track of which features belong to which image 
    featInd(n:n+currCount) = i;
    
    for j=1:currCount
        
        currFeat=strongestSURFfeatures{i}(j);
        
        inputFeat(:,n)=[double(currFeat.Scale); double(currFeat.SignOfLaplacian);...
            double(currFeat.Orientation); double(currFeat.Location(1));...
            double(currFeat.Location(2)); double(currFeat.Metric)] ;
        n=n+1;
    end
    

end
save('featInd.mat', 'featInd');

%% saving SURF features from testing images to array 
n=1;

for i = trainingLength+1:testingLength+trainingLength
    
    currCount = strongestSURFfeatures{i}.Count;
    
    %lookup table to keep track of which features belong to which image 
    testFeatInd(n:n+currCount) = i;
    
    for j=1:currCount        
        currFeat=strongestSURFfeatures{i}(j);
        
        testFeat(:,n)=[double(currFeat.Scale); double(currFeat.SignOfLaplacian);...
            double(currFeat.Orientation); double(currFeat.Location(1));...
            double(currFeat.Location(2)); double(currFeat.Metric)] ;
        n=n+1;
    end
end
save('testFeatInd.mat', 'testFeatInd');




%% creating lsh data structure for input features
addpath('../lshcode');
Te=lsh('e2lsh', 50,20,size(inputFeat,1), inputFeat, 'range', 255, 'w', -4);

%% Find lsh matches and their consensus:
tic
rNN=50; %number of desired matches for lsh
bestMatch = zeros(testingLength, 1);
best=[];

%go through every test image:
currTestFeat = 1;
threshold=3;
j=1;
svmInput=[];
for currImg = (trainingLength + 1):(trainingLength + testingLength)
    %do lsh on every feature of the current image, and keep a tally:
    tally = [];
    featTally=[featInd' zeros(length(featInd),1)];
   
    while (testFeatInd(currTestFeat) == currImg) && (currTestFeat <= length(testFeat))
        %iNN = indecides of matches, numcand = number of examined
        %candidates in the lookup table 
        [iNN,numcand]=lshlookup(testFeat(:,currTestFeat),inputFeat,Te,'k',rNN);
        
        %add all hits for this feature to the tally for the current image:
        for i=1:length(iNN)
            %find what image number this feature is from:
            hitImg = featInd(iNN(i));
            
            if isempty(tally)
                %this is the first feature in the tally:
                tally(1, 1:2)=[hitImg 1];
            else
                %check to see if we've already found this feature's image:
                index=find(hitImg == tally(:,1));
                if ~isempty(index)
                    %we've found this image before, so increment tally:
                    tally(index,2)=tally(index,2)+1;
                else
                    %new image, so add a spot for it with a count of 1:
                    tally(end+1,:)=[hitImg 1];
                end
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
    
%store test images ids with consensus below a threshold in a separate array


    if best(1,2)<threshold
        
        %keeping a tally of the features LSH hit with currTestFeat
        for j=1:length(iNN)
                %go through nearest neighbor features returned and update tally for
                %each 
                featTally(iNN(j),2)=featTally(iNN(j),2)+1;
        end
    end
    
end


%% output results to files so that we can check the official IRMA error:

%TODO: if no match was found, we have a 0 -- for now, we'll pretend
%it's a random image to make things work out:
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

fileID = fopen('output.txt', 'w');
for i=1:testingLength
    %now look up the real ID of each test image:
    currID = realImageIDs(i+trainingLength);
    %and also that of its best match, and use that to retrieve its IRMA code:
    matchID = realImageIDs(bestMatch(i));
    matchIRMA = irmaCSV(tempCSV == matchID, 2);
    
    
    fprintf(fileID, '%d %s\n', currID, matchIRMA{1});
end
toc
%% saving images with bad consensus to file for input to svm
tempCSVtest=cell2mat(irmaCSVtest(:,1));
for i=1:length(svmInput)
    svmFeat(i)=strongestSURFfeatures(svmInput(i));
    svmIRMAClass(i)=irmaCSVtest(find(realImageIDs(svmInput(i))== tempCSVtest(:,1)), 3)
end

saveSURFtoFile('svmInput.txt', svmFeat, 0, svmIRMAClass);


%% was for saving the ground truth to a form the python error script can read:
% fileID = fopen('outputIRMAtestclasses.txt', 'w');
% for i=1:1733
%     fprintf(fileID, '%d %s\n', ImageCLEFmed2009testcodes{i,1}, ImageCLEFmed2009testcodes{i,2});
% end