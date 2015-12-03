function [  ] = saveSURFtoFile( path, features )
%UNTITLED3 Summary of this function goes here
%   Detailed explanation goes here

file = fopen(path, 'w');

for i=1:length(features)
    %for every image, save a single line for each of its strongest features
    for j=1:length(features{i})
        
        %TODO: writing these is really slow; making a copy of each feature
        %is perhaps slightly faster?  Surely there is a better way...
        %fprintf(file, '%f %f %f %f %f %f\n', features{1}(j).Scale, features{1}(j).SignOfLaplacian, features{1}(j).Orientation, features{1}(j).Location, features{1}(j).Metric); 
        
        currFeat = features{1}(j);
        fprintf(file, '%f %f %f %f %f %f\n', currFeat.Scale, currFeat.SignOfLaplacian, currFeat.Orientation, currFeat.Location, currFeat.Metric); 

    end
end

