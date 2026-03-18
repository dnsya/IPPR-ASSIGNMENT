function [filledMask, scaleFactor, img, grayImg] = glovePreprocess(img)
    % Store original image size
    [origH, ~, ~] = size(img);
    
    % Resize for processing
    img = imresize(img, [1920 NaN]);
    [resizedH, ~, ~] = size(img);
    scaleFactor = origH / resizedH;
    
    % Glove mask
    grayImg = imgaussfilt(rgb2gray(img), 2);
    bwImg = imbinarize(grayImg, graythresh(grayImg));
    bwImg = bwareaopen(bwImg, 2000);
    bwImg = imclose(bwImg, strel('disk', 3));
    filledMask = imfill(bwImg, 'holes');
    filledMask = bwareafilt(filledMask, 1);
    
end