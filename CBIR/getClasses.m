%clc; clear all; close all;
testPath = fopen('../../IRMA/2009/Catergories/08-classes.txt');
classes = textscan(testPath, '%d;%s');
fclose(testPath);
celldisp(classes)

for i=1:length(classes{1}(:))
    codes{i} = strsplit(char(classes{2}{i}), '-')
    %separate all things from an nx1 cell array into an nx4 cell array
    %for j=1:length(codes{i}) 
        %codes2a{i,j} = codes{i}{j};
        codes2a{i} = codes{i}{1};
        codes2b{i} = codes{i}{2};
        codes2c{i} = codes{i}{3};
        codes2d{i} = codes{i}{4};
    %end
end
%%
% get all possible classes for each code section:
codes3{:,1} = unique(codes2a);
codes3{:,2} = unique(codes2b);
codes3{:,3} = unique(codes2c);
codes3{:,4} = unique(codes2d);

% for i=1:length(classes{1}(:))
%     for j=1:length(codes{i})
%         codesHex{i,j} = hex2dec(codes{i}{j});
%     end
% end

%% make class files for each section of the code:

for i=1:4
    
    
end