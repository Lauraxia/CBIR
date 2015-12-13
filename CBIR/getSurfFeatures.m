%% load all IRMA training and testing images:
trainPath = '../../IRMA/2009/Training Data/ImageCLEFmed2009_train.02/';
path = sprintf('%s*.png', trainPath);
files = dir(path);

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

%% calculate SURF features for them (using a low enough threshold to guarantee a min number of features to use)
numSURF=10;
features = cell(1, length(files));
strongestfeatures = cell(1, length(files));
fprintf('Progress:\n');
fprintf(['\n' repmat('.',1,(floor(length(files)/100))) '\n\n']);

%calculate SURF features for them (using a low enough threshold to
%guarantee a min number of features to use)
parfor i=1:length(files)
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
testPath = fopen('../../IRMA/2009/Catergories/08-classes.txt');
classes = textscan(testPath, '%d;%s');
fclose(testPath);

%sort the classes, so easier to find matches:
[test, ind] = sort(classes{1,2})

%%
%load csv with irma code for each image, then match up with what class that is:
%workaround to avoid strange readtable/etc bug -- saved as a mat
load('irmaCSV.mat')
load('irmaCSVtest.mat')

for i=1:length(irmaCSV)
    irmaCSV{i,3} = find(strcmp(classes{2}, irmaCSV{i,2}));
    
    %so we'll know if something wasn't found:
    if irmaCSV{i,3} == 0 
       fprintf('very bad %d\n', i);
    end
end
%%
for i=1:length(irmaCSVtest)
    irmaCSVtest{i,3} = find(strcmp(classes{2}, irmaCSVtest{i,2}));
    
    %so we'll know if something wasn't found:
    if irmaCSVtest{i,3} == 0 
       fprintf('very bad %d\n', i);
    end
end
%%
saveSURFtoFile('training.txt', strongestSURFfeatures(1:trainingLength), 10, irmaCSV(:,3));
saveSURFtoFile('testing.txt', strongestSURFfeatures(trainingLength+1:end), 10, irmaCSVtest(:,3));

%% calculate radon barcodes (RBCs) for each image 
addpath('../');
i=1;
for file = files'
    barcode{i} = extractRBC(irma{i}, 32, 32, 8, false);
    i=i+1;
    fprintf('Extracting barcodes for image %d \r', i); 
end

%% calculate brisk features for images
i=1;
for file = files'
    BRISKfeatures{i} = detectBRISKFeatures(irma{i}, 'MinContrast', 0.1);
    strongestBRISKfeatures{i} = BRISKfeatures{i}.selectStrongest(10); 
    i=i+1;
    fprintf('Calculating BRISK features for %d \r', i);
end


%% saving features from training images to array for input to lsh
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

%% saving features from testing images to array 
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

%% creating lsh data structure for input features
addpath('../lshcode');
Te=lsh('e2lsh', 50,30,size(inputFeat,1), inputFeat, 'range', 255, 'w', -4);


%% providing query feature to lsh to find closest matches 

rNN=21; %?!?!
%read in csv file provided for IRMA database as a table data structure
%%
%TODO: this is a super hackish way to make the relative path absolute
%before passing to a function, to work around MATLAB bug with readtable...
%still not working unless you use an absolute path *from command window*
% currAbsPath = cd;
% cd ../..;
% newPath = cd;
% filepath= sprintf('%s/IRMA/2009/Irma Code Training/ImageCLEFmed2009_train_codes.02.csv', newPath)
% cd(currAbsPath);
% t=readtable(filepath, 'Delimiter', ';');
% 
% %convert table to structured array 
% c=table2struct(t(:,1:2));

%go through every test image:
currTestFeat = 1;
for currImg = (trainingLength + 1):(trainingLength + testingLength)
    
    %do lsh on every feature of the current image, and keep a tally:
    tally = [];
    while (testFeatInd(currTestFeat) == currImg) && (currTestFeat <= length(testFeat))
        %iNN = indecides of matches, numcand = length of iNN?! except
        %apparently it isn't.... TODO look up
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
    sum(tally(:,2)>1)

end 
    
%%
%extracting IRMA codes of the closest matches obtained through LSH by
%providing indexes and path to csv file containing IRMA codes, and writing
%them to a file 


%extractIRMAcode function needs to be modified

%extracting IRMA codes of the closest matches obtained through LSH by
%providing indexes and path to csv file containing IRMA codes, and writing
%them to a file 
%extractIRMAcode(c, imgnum);
%type test.txt


