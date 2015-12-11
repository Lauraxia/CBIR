clc, clear all, close all

%% params:
dir = '';

%% load training data for svm:
path = sprintf('%straining.txt', dir);
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

%% LIBSVM setup:
% addpath to the libsvm toolbox and data
addpath('../libsvm/matlab');
dirData = '../libsvm';
addpath(dirData);

%% rebalance data to avoid training bias:
%TODO: we have 193 classes, not 2... fix this later, for now just ignore
% bias = mean(trainingData(:,1))
% if (bias > 0.5) 
%     skew = 1;
% end
% %i=0;
% while ((bias < 0.47 || bias > 0.53))% && i<10000)
%     for i=1:10
%         x = randi([1, length(trainingData(:,1))]);
%         if (trainingData(x,1) == skew)
%             trainingData(x,:) = [];
%         end
%     end
%     bias = mean(trainingData(:,1));
%     %i=i+1;
% end
% bias
%% train svm:
%TODO use grid search to determine optimal c and g values!
model = svmtrain(trainingData(:, 1), double(trainingData(:, 2:end)), '-s 0 -t 2 -m 2500 -h 0'); %disable -h 0?
display('Training complete.');

% save model information for next time:
save('model.mat', 'model');

%% test with the following images:

% to load saved model:
%load('model.mat', 'model');

path2 = sprintf('%stesting.txt', dir);
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
