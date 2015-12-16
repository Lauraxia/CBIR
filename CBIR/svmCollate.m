
%% if collating results from multiple classifiers (1 per code section)
paths = {'_sub1', '_sub2', '_sub3', '_sub4'};
fdir = '';


%% load match data to collate:


for i=1:length(paths)
    uniqueFileID = paths{i};
    path = sprintf('%ssvmMatchOutput%s.txt', fdir, uniqueFileID);
    matchData(i,:) = csvread(path);
    
end

%temp fix for where we have no results...
matchData(matchData == 0) = 1;
%%
for i=1:length(matchData(1,:))
    for j=1:length(paths)
        matchCodes(j,i) = codes3{j}(matchData(j,i));
    end
irmaCode{i} = sprintf('%s-%s-%s-%s', matchCodes{:,i});

end
%%
savePath = sprintf('svmoutput_collated.txt');
fileID = fopen(savePath, 'w');
for i=1:testingLength
    %now look up the real ID of each test image:
    currID = realImageIDs(i+trainingLength);
    fprintf(fileID, '%d %s\n', currID, irmaCode{i});
end