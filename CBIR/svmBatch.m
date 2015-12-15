clc, clear all, close all

%% params:
fdir = '';

%% load training data for svm:
path = sprintf('%straining.txt', fdir);
trainingData = csvread(path);

%% find normalization factors:
numFeatures = length(trainingData(1,:))-1;
scalingFactors = ones(numFeatures,1);
for i=1:numFeatures
    scalingFactors(i) = max(trainingData(:, i+1));
    if (scalingFactors(i) == 0) %corner case, so not NaN
        scalingFactors(i) = 1;
    end
    trainingData(:, i+1) = trainingData(:, i+1) ./ scalingFactors(i);
end
save('scalingFactors.mat', 'scalingFactors');
%TODO: handling negative data?!

%% load things needed to find consensus:
load('testFeatInd.mat');
load('trainingTestingLengths.mat');

%% rebalance data to avoid training bias:

%find how many training features of each class exist:
freq = hist(trainingData(:,1), 193);

%we want to get rid of some from classes that have too many
%TODO: play around with threshold -- they are still pretty unbalanced, but
%not all classes are well-represented...
threshold = median(freq)*2;
numToCull = freq - threshold;
culledTrainingLength = trainingLength;

for i=1:length(freq)
    if (numToCull(i) > 0)
        %these are the training elements equal to i, which we will cull some of:
        cullCanditates = find(trainingData(:,1) == i);
        %pick the desired amount of indices randomly:
        spotsToCull = randperm(freq(i), numToCull(i));

        %and remove them from the trainingData, and trainingLength: 
        trainingData(cullCanditates(spotsToCull), :) = [];
        %testFeatInd(cullCanditates(spotsToCull)) = [];
        culledTrainingLength = culledTrainingLength - numToCull(i);
    end
end

%% LIBSVM setup:
% addpath to the libsvm toolbox and data
addpath('../libsvm/matlab');
dirData = '../libsvm';
addpath(dirData);

%% train svm:
%TODO use grid search to determine optimal c and g values!
model = svmtrain(trainingData(:, 1), double(trainingData(:, 2:end)), '-s 0 -t 2 -m 2500 -h 0'); %disable -h 0?
display('Training complete.');

% save model information for next time:
save('model.mat', 'model');

%% test with the following images:

% to load saved model:
%load('model.mat', 'model');

path2 = sprintf('%stesting.txt', fdir);
testingData = csvread(path2);

% scale:
load('scalingFactors.mat', 'scalingFactors');
for j=1:(length(testingData(1,:))-1)
    testingData(:, j+1) = testingData(:, j+1) ./ scalingFactors(j);
end

%parfor i=1:length(testingData)
    [predict_label, accuracy, prob_values] = svmpredict(testingData(:, 1), double(testingData(:, 2:end)), model);
%end

%% Save results:
outpath = sprintf('%spredict.txt', fdir);
save(outpath, predict_label);
outpath = sprintf('%saccuracy.txt', fdir);
save(outpath, accuracy);
outpath = sprintf('%sprob.txt', fdir);
save(outpath, prob_values);


%% Find the consensus between each feature:

bestMatch = zeros(testingLength, 1);

%go through every test image:
currTestFeat = 1;
for currImg = (culledTrainingLength + 1):(culledTrainingLength + testingLength)
    
    %find classification result for every feature of the current image, and keep a tally:
    tally = [];
    while (testFeatInd(currTestFeat) == currImg) && (currTestFeat < length(testFeatInd))
        
        %find what IRMA class this feature was classified as:
        hitImgClass = predict_label(currTestFeat);
        
        if isempty(tally)
            %this is the first feature in the tally:
            tally(1, 1:2)=[hitImgClass 1];
        else
            %check to see if we've already found this feature's image:
            index=find(hitImgClass == tally(:,1));
            if ~isempty(index)
                %we've found this image before, so increment tally:
                tally(index,2)=tally(index,2)+1;
            else
                %new image, so add a spot for it with a count of 1:
                tally(end+1,:)=[hitImgClass 1];
            end
        end
        currTestFeat = currTestFeat + 1;
    end
    
    %now we've done all features of the current image, so check the
    %consensus:
    if isempty(tally)
        fprintf('Nothing found! :( %d\n', currImg);
        bestMatch(currImg - culledTrainingLength) = 0;
    else
        %sum(tally(:,2)>1);
        best = sortrows(tally, -2);
        bestMatch(currImg - culledTrainingLength) = best(1,1);
        best(1,1:2)
    end
end 
    
%% output results to files so that we can check the official IRMA error:

%TODO: if no match was found, we have a 0 -- for now, we'll pretend
%it's a random image to make things work out:
bestMatch(bestMatch == 0) = 1;

%convert training, testing indices to actual image ids:
realImageIDs = zeros(length(files), 1);
i=1;
for file = files'
    %remove file extension and get the image number from filename:
    realImageIDs(i) = str2double(regexprep(file.name, '.png', ''));
    if isnan(realImageIDs(i) )
        fprintf('%s isnan!!!\n', file.name);
    end
    i=i+1;
end
%%

fileID = fopen('svmoutput.txt', 'w');
for i=1:testingLength
    %now look up the real ID of each test image:
    currID = realImageIDs(i+trainingLength);
    %and also the best guess at its IRMA code:
    matchIRMA = classes{1,2}(bestMatch(i));    
    fprintf(fileID, '%d %s\n', currID, matchIRMA{1});
end