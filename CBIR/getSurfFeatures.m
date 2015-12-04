%load all IRMA training images:
dirpath = '../../IRMA/2009/Training Data/ImageCLEFmed2009_train.02/';
path = sprintf('%s/*.png', dirpath);
files = dir(path);

i=1;
for file = files'
   irma{i} = imread(sprintf('%s/%s', dirpath, file.name));
   
   %any 3-channel images seem to be the same for all colour channels, so we
   %can just remove all but channel 1:
   if (length(irma{i}(1,1,:)) == 3)
       irma{i}(:,:,2:3) = [];
   end
   %TODO: filter the 3-channel greyscale images to 1-channel, and make sure
    %nothing is actually colour, or we'll need to handle that differently
   
   i = i+1;
end


%%

%calculate SURF features for them (using a low enough threshold to
%guarantee a min number of features to use)
i=1;
for file = files'
   SURFfeatures{i} = detectSURFFeatures(irma{i}, 'MetricThreshold', 200);
   strongestSURFfeatures{i}=SURFfeatures{i}.selectStrongest(10);
   i = i+1;
   fprintf('Calculating SURF features for %d \r', i);
end

%%

saveSURFtoFile('SURFfeatures.txt', strongestSURFfeatures);
%%


%calculate radon barcodes (RBCs) for each image 
i=1;
for file = files'
    barcode{i} = extractRBC(irma{i}, 32, 32, 8, false);
    i=i+1;
    fprintf('Extracting barcodes for image %d \r', i); 
end

%%

%calculate brisk features for images
i=1;
for file = files'
    BRISKfeatures{i} = detectBRISKFeatures(irma{i}, 'MinContrast', 0.1);
    strongestBRISKfeatures{i} = BRISKfeatures{i}.selectStrongest(10); 
    i=i+1;
    fprintf('Calculating BRISK features for %d \r', i);
end
    
    

