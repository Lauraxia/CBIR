%% Generate irmaCSV and irmaCSVtest:
testPath = fopen('../../IRMA/2009/Catergories/08-classes.txt');
classes = textscan(testPath, '%d;%s');
fclose(testPath);

%sort the classes, so easier to find matches:
[test, ind] = sort(classes{1,2})

%% find classes for each subsection:
for i=1:length(classes{1}(:))
    codes{i} = strsplit(char(classes{2}{i}), '-')
    
    %separate all things from an nx1 cell array into an nx4 cell array
    codes2a{i} = codes{i}{1};
    codes2b{i} = codes{i}{2};
    codes2c{i} = codes{i}{3};
    codes2d{i} = codes{i}{4};
end

% get all possible classes for each code section:
codes3{:,1} = unique(codes2a);
codes3{:,2} = unique(codes2b);
codes3{:,3} = unique(codes2c);
codes3{:,4} = unique(codes2d);

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
    
    %find subcode classes too:
    splitted = strsplit(char(irmaCSV{i,2}), '-');
    for j=1:4
        irmaCSV{i,j+3} = find(strcmp(codes3{1,j}, splitted{j}));
        if irmaCSV{i,j+3} == 0 
           fprintf('very bad %d\n', i);
        end
    end
end
%%
for i=1:length(irmaCSVtest)
    irmaCSVtest{i,3} = find(strcmp(classes{2}, irmaCSVtest{i,2}));
    
    %so we'll know if something wasn't found:
    if irmaCSVtest{i,3} == 0 
       fprintf('very bad %d\n', i);
    end
    
    %find subcode classes too:
    splitted = strsplit(char(irmaCSVtest{i,2}), '-');
    for j=1:4
        irmaCSVtest{i,j+3} = find(strcmp(codes3{1,j}, splitted{j}));
        if irmaCSVtest{i,j+3} == 0 
           fprintf('very bad %d\n', i);
        end
    end
end

%%

% for i=1:length(classes{1}(:))
%     for j=1:length(codes{i})
%         codesHex{i,j} = hex2dec(codes{i}{j});
%     end
% end

%%
save('irmaCSV.mat', 'irmaCSV');
save('irmaCSVtest.mat', 'irmaCSVtest');

save('classes.mat', 'classes');