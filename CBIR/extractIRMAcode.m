function [c] = extractIRMAcode(c, imgnum)
%filepath is path to csv file
%imgnum is the index of the image in IRMA database


%read the corresponding IRMA code of the image using its index 
%in the cell
for i=1:size(imgnum,2)
    imageID(i,:)=[c(imgnum(i)).image_id]; %extract image ID
    IRMAcode(i,:)=[c(imgnum(i)).irma_code]; %extract IRMA code 
    

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