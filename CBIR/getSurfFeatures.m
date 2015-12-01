%load all IRMA training images:
dirpath = '../../IRMA/2009/Training Data/ImageCLEFmed2009_train.02/';
path = sprintf('%s/*.png', dirpath);
files = dir(path);

i=1;
for file = files'
   irma{i} = imread(sprintf('%s/%s', dirpath, file.name));
   i = i+1;
end
%TODO: filter the 3-channel greyscale images to 1-channel, and make sure
%nothing is actually colour, or we'll need to handle that differently

%%

%calculate SURF features for them (using a low enough threshold to
%guarantee a min number of features to use)
i=1;
for file = files'
   features{i} = detectSURFFeatures(irma{i}, 'MetricThreshold', 200);
   strongestfeatures{i}=features{i}.selectStrongest(10);
   i = i+1;
   fprintf('%d\n', i);
end