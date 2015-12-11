function [imageID, IRMAcode] = extractIRMAcode(filepath, imgnum)
%filepath is path to csv file
%imgnum is the index of the image in IRMA database

%read in csv file provided for IRMA database as a table data structure
t=readtable(filepath, 'Delimiter', ';');

%convert table to cell structure
c=table2struct(t(:,1:2));

%read the corresponding IRMA code of the image using its index 
%in the cell
for i=1:size(imgnum,2)
    imageID(i,:)=[c(imgnum(i)).image_id];
    IRMAcode(i,:)=[c(imgnum(i)).irma_code];
    i=i+1;
end

%write the IRMA codes to a text file
fileID=fopen('test.txt', 'w')
formatspec='%d %s\n';

for i=1:size(IRMAcode,1)
    
    fprintf(fileID, formatspec, imageID(i,:), IRMAcode(i,:));
    i=i+1;
    
end

fclose(fileID);


end