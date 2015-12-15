%% calculate brisk features for images
i=1;
for file = files'
    BRISKfeatures{i} = detectBRISKFeatures(irma{i}, 'MinContrast', 0.1);
    strongestBRISKfeatures{i} = BRISKfeatures{i}.selectStrongest(10); 
    fprintf('Calculating BRISK features for %d \r', i);
    i=i+1;
end


%% saving BRISK features from training images to array for input to lsh
n=1;

for i =1:trainingLength
    currCount = strongestBRISKfeatures{i}.Count;
    
    %lookup table to keep track of which features belong to which image 
    featInd(n:n+currCount) = i;
    
    for j=1:currCount
        
        currFeat=strongestBRISKfeatures{i}(j);
        
        inputFeat(:,n)=[double(currFeat.Scale); double(currFeat.Orientation);...
            double(currFeat.Location(1)); double(currFeat.Location(2));...
            double(currFeat.Metric)] ;
        n=n+1;
    end
    

end
save('featInd.mat', 'featInd');

%% saving BRISK features from testing images to array 
n=1;

for i = trainingLength+1:testingLength+trainingLength
    
    currCount = strongestBRISKfeatures{i}.Count;
    
    %lookup table to keep track of which features belong to which image 
    testFeatInd(n:n+currCount) = i;
    
    for j=1:currCount        
        currFeat=strongestBRISKfeatures{i}(j);
        
        testFeat(:,n)=[double(currFeat.Scale); double(currFeat.Orientation);...
            double(currFeat.Location(1)); double(currFeat.Location(2)); 
            double(currFeat.Metric)] ;
        n=n+1;
    end
end
save('testFeatInd.mat', 'testFeatInd');