function [ ] = extractIRMAcode(filepath, imgnum)
%filepath is path to csv file
%imgnum is the index of the image in IRMA database

%read in csv file provided for IRMA database as a table data structure
t=readtable(filepath, 'Delimiter', ';');

%convert table to cell structure
c=table2cell(t);

%read the corresponding IRMA code of the image using its index 
%in the cell
for i=1:size(imgnum,2)
    IRMAcode{i}=c(find([c{:,1}] == imgnum(i)),2);
    i=i+1;
end 