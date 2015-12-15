%% Generate irmaCSV and irmaCSVtest:
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
save('irmaCSV.mat', 'irmaCSV');
save('irmaCSVtest.mat', 'irmaCSVtest');