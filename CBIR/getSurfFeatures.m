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

%%
saveSURFtoFile('trainingFeatures.txt', strongestSURFfeatures(1:trainingLength), 10);
saveSURFtoFile('testingFeatures.txt', strongestSURFfeatures(trainingLength+1:end), 10);

%% calculate radon barcodes (RBCs) for each image 
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
    
    for j=1:strongestSURFfeatures{i}.Count
        
        currFeat=strongestSURFfeatures{i}(j);
        
        inputFeat(:,n)=[double(currFeat.Scale); double(currFeat.SignOfLaplacian);...
            double(currFeat.Orientation); double(currFeat.Location(1));...
            double(currFeat.Location(2)); double(currFeat.Metric)] ;
        
        %lookup table to keep track of which features belong to which
        %image 
        featInd(n,1:2) = [i n];
        n=n+1;
    end
    

end

%% saving features from testing images to array 
% this needs to be fixed!!

% n=1;
% 
% for i = trainingLength+1:testingLength+trainingLength
%     
%     for j=1:length(strongestSURFfeatures{i})
%         
%         currFeat=strongestSURFfeatures{i}(j);
%         
%         testFeat(:,n)=[double(currFeat.Scale); double(currFeat.SignOfLaplacian);...
%             double(currFeat.Orientation); double(currFeat.Location(1));...
%             double(currFeat.Location(2)); double(currFeat.Metric)] ;
%         
%        
%         n=n+1;
%     end
% end


%% creating lsh data structure for input features
Te=lsh('e2lsh', 50,25,size(inputFeat,1), inputFeat, 'range', 255, 'w', -3);

%% providing query feature to lsh to find closest matches 

rNN=21;
j=1;
tally=zeros((rNN)*numSURF,2);
%read in csv file provided for IRMA database as a table data structure
filepath='../../IRMA/2009/IRMA Code Training/ImageCLEFmed2009_train_codes.02.csv';
t=readtable(filepath, 'Delimiter', ';');

%convert table to structured array 
c=table2struct(t(:,1:2));

for m=1:1
[iNN,numcand]=lshlookup(inputFeat(:,m),inputFeat,Te,'k',rNN);

%read image indexes of closest matches
for i=1:length(iNN)
    imgnum(i)=featInd(find(iNN(i)==featInd(:,2)),1);
    
%keep a tally of images matched to each feature of input image 
%currently not working, giving an error 'Index exceeds matrix dimensions'
    
% index=find((c(imgnum(i)).image_id==tally(:,1)))
%  
%     if isempty(index)==0
%         tally(index,2)=tally(index,2)+1;
%     else
%         tally(j,:)=[c(imgnum(i)).image_id; 1];
%         j=j+1;
%       
%     end
%     

end;
    
%extractIRMAcode function needs to be modified

%extracting IRMA codes of the closest matches obtained through LSH by
%providing indexes and path to csv file containing IRMA codes, and writing
%them to a file 
%extractIRMAcode(c, imgnum);
%type test.txt

end;





    
    

