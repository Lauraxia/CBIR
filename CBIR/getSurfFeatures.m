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
features = cell(1, length(files));
strongestfeatures = cell(1, length(files));
fprintf('Progress:\n');
fprintf(['\n' repmat('.',1,(floor(length(files)/100))) '\n\n']);

%calculate SURF features for them (using a low enough threshold to
%guarantee a min number of features to use)
parfor i=1:length(files)
   SURFfeatures{i} = detectSURFFeatures(irma{i}, 'MetricThreshold', 200);
   strongestSURFfeatures{i}=SURFfeatures{i}.selectStrongest(10);

   %fprintf('Calculating features for %d \n', i);
   if mod(i,100) == 0
   fprintf('\b|\n');
   end
end

%%
saveSURFtoFile('trainingFeatures.txt', strongestSURFfeatures(1:trainingLength), 10, );
saveSURFtoFile('testingFeatures.txt', strongestSURFfeatures(trainingLength+1:end), 10);

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


%% saving features to array for input to lsh
n=1;

for i = 1:5
    
    for j=1:length(strongestSURFfeatures{i})
        
        currFeat=strongestSURFfeatures{i}(j);
        
        inputFeat(:,n)=[double(currFeat.Scale); double(currFeat.SignOfLaplacian);...
            double(currFeat.Orientation); double(currFeat.Location(1));...
            double(currFeat.Location(2)); double(currFeat.Metric)] ;
        
        j=j+1;
        n=n+1;
    end
    i=i+1;
end


%% creating lsh data structure for input features
addpath('../lshcode');
Te=lsh('e2lsh', 50,30,size(inputFeat,1), inputFeat, 'range', 255, 'w', -4);

%% providing query feature to lsh to find closest matches 
[iNN,numcand]=lshlookup(inputFeat(:,8),inputFeat,Te,'k',11);

%read image indexes of closest matches
for i=1:length(iNN)
    imgnum(i)=floor(iNN(i)/10)+1;
    i=i+1;
end
%%
%TODO: this is a super hackish way to make the relative path absolute
%before passing to a function, to work around errors with readtable
currAbsPath = cd;
cd ../..;
newPath = cd;
filepath= sprintf('%s/IRMA/2009/Irma Code Training/ImageCLEFmed2009_train_codes.02.csv', newPath)
cd(currAbsPath);
imgnum = 10
%extracting IRMA codes of the closest matches obtained through LSH by
%providing indexes and path to csv file containing IRMA codes, and writing
%them to a file 
extractIRMAcode(filepath, imgnum);
    

%%
%getAllIRMACodes(
