function [  ] = saveSURFtoFile( path, features, subsetIncrement )
%UNTITLED3 Summary of this function goes here
%   Detailed explanation goes here

%if a third argument has been specified, we will also save a subset of
%every (subsetIncrement) points to another file:
switch nargin
    case 2
        saveSubset = false;
    otherwise
        saveSubset = true;
        subsetFile = fopen(sprintf('%s_subset_%d.txt', path, subsetIncrement), 'w'); 
end
    
file = fopen(path, 'w');

for i=1:length(features)
    
    %determine if this should be included in our subset file:
    printSub = saveSubset && (mod(i, subsetIncrement) == 0);
    
    %for every image, save a single line for each of its strongest features
    for j=1:length(features{i})
        
        %TODO: writing these is really slow; making a copy of each feature
        %is perhaps slightly faster?  Surely there is a better way...
        %fprintf(file, '%f %f %f %f %f %f\n', features{1}(j).Scale, features{1}(j).SignOfLaplacian, features{1}(j).Orientation, features{1}(j).Location, features{1}(j).Metric); 
        
        currFeat = features{1}(j);
        currString = sprintf('%f %f %f %f %f %f\n', currFeat.Scale, currFeat.SignOfLaplacian, currFeat.Orientation, currFeat.Location, currFeat.Metric); 
        fprintf(file, currString);    
        
        %if this is within our subset, save to subset file too:
        if printSub
            fprintf(subsetFile, currString);
        end
    end
end

