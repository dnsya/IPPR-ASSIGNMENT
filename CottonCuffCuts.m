function [resultImg, numCuts, cutPercentage, processingTime] = CottonCuffCuts(img)
    % CottonCuffCuts - Detects cuff cuts in cotton gloves
    tic;
    
    % Grayscale Conversion
    if size(img, 3) == 3
        grayImg = rgb2gray(img);
    else
        grayImg = img;
    end
    
    [rows, cols] = size(grayImg);
    
    % ROI Extraction - bottom 30%
    roiMask = zeros(rows, cols);
    cuffStartRow = round(rows * 0.70);
    roiMask(cuffStartRow:end, :) = 1;
    roiImg = grayImg .* uint8(roiMask);
    
    % Histogram Equalization
    equalizedImg = histeq(roiImg);
    equalizedImg = imadjust(equalizedImg, stretchlim(equalizedImg, [0.01 0.99]), []);
    
    % Sobel Edge Enhancement
    sobelH = fspecial('sobel');
    sobelV = sobelH';
    edgeH = imfilter(double(equalizedImg), sobelH, 'replicate');
    edgeV = imfilter(double(equalizedImg), sobelV, 'replicate');
    sobelImg = sqrt(edgeH.^2 + edgeV.^2);
    sobelImg = uint8(255 * mat2gray(sobelImg));
    
    % Canny Edge Detection
    edgeMap = edge(sobelImg, 'Canny', [0.05, 0.20]);
    
    % Morphological Dilation
    se = strel('line', 7, 0);
    dilatedEdges = imdilate(edgeMap, se);
    se2 = strel('disk', 3);
    dilatedEdges = imdilate(dilatedEdges, se2);
    filledEdges = imfill(dilatedEdges, 'holes');
    filledEdges = bwareaopen(filledEdges, 30);
    
    % Connected Component Analysis
    [labeledImg, numRegions] = bwlabel(filledEdges);
    
    if numRegions == 0
        if size(img, 3) == 3
            resultImg = img;
        else
            resultImg = cat(3, img, img, img);
        end
        numCuts = 0;
        cutPercentage = 0;
        processingTime = toc(startTime);
        return;
    end
    
    stats = regionprops(labeledImg, 'Area', 'BoundingBox', 'Perimeter', ...
                        'MajorAxisLength', 'MinorAxisLength', 'Eccentricity', ...
                        'Solidity', 'PixelIdxList');
    
    % Feature Extraction
    cutFeatures = [];
    validCutIndices = [];
    
    for i = 1:numRegions
        area = stats(i).Area;
        perimeter = stats(i).Perimeter;
        majorAxis = stats(i).MajorAxisLength;
        minorAxis = stats(i).MinorAxisLength;
        
        cutLength = majorAxis;
        
        if minorAxis > 0
            aspectRatio = majorAxis / minorAxis;
        else
            aspectRatio = 0;
        end
        
        if perimeter > 0
            edgeContinuity = (4 * pi * area) / (perimeter^2);
        else
            edgeContinuity = 0;
        end
        
        eccentricity = stats(i).Eccentricity;
        solidity = stats(i).Solidity;
        
        cutFeatures = [cutFeatures; cutLength, aspectRatio, area, edgeContinuity, eccentricity, solidity];
        validCutIndices = [validCutIndices; i];
    end
    
    % Defect Recognition
    cutDetected = false(numRegions, 1);
    
    for i = 1:size(cutFeatures, 1)
        bbox = stats(validCutIndices(i)).BoundingBox;
        yPos = bbox(2);
        inCuffRegion = (yPos > cuffStartRow);
        
        if cutFeatures(i, 3) > 40 && cutFeatures(i, 2) > 1.8 && ...
           cutFeatures(i, 1) > 15 && cutFeatures(i, 5) > 0.6 && inCuffRegion
            cutDetected(i) = true;
        end
    end
    
    numCuts = sum(cutDetected);
    
    totalImageArea = rows * cols;
    if numCuts > 0
        totalCutArea = sum(cutFeatures(cutDetected, 3));
        cutPercentage = (totalCutArea / totalImageArea) * 100;
    else
        cutPercentage = 0;
    end
    
    % Visualization
    if size(img, 3) == 3
        resultImg = img;
    else
        resultImg = cat(3, img, img, img);
    end
    
    [rows, cols, ~] = size(resultImg);
    
    % Draw red bounding boxes
    for i = 1:length(validCutIndices)
        if cutDetected(i)
            bbox = stats(validCutIndices(i)).BoundingBox;
            x1 = max(1, round(bbox(1)));
            y1 = max(1, round(bbox(2)));
            x2 = min(cols, round(bbox(1) + bbox(3)));
            y2 = min(rows, round(bbox(2) + bbox(4)));
            
            % 3-pixel thick red rectangle
            for t = 0:2
                if y1+t >= 1 && y1+t <= rows
                    resultImg(y1+t, x1:x2, 1) = 255; resultImg(y1+t, x1:x2, 2:3) = 0;
                end
                if y2-t >= 1 && y2-t <= rows
                    resultImg(y2-t, x1:x2, 1) = 255; resultImg(y2-t, x1:x2, 2:3) = 0;
                end
                if x1+t >= 1 && x1+t <= cols
                    resultImg(y1:y2, x1+t, 1) = 255; resultImg(y1:y2, x1+t, 2:3) = 0;
                end
                if x2-t >= 1 && x2-t <= cols
                    resultImg(y1:y2, x2-t, 1) = 255; resultImg(y1:y2, x2-t, 2:3) = 0;
                end
            end
        end
    end
    
    % Draw yellow ROI boundary line
    if cuffStartRow > 1 && cuffStartRow <= rows
        for t = -1:1
            if cuffStartRow+t >= 1 && cuffStartRow+t <= rows
                resultImg(cuffStartRow+t, :, 1) = 255;
                resultImg(cuffStartRow+t, :, 2) = 255;
                resultImg(cuffStartRow+t, :, 3) = 0;
            end
        end
    end
    
    processingTime = toc;
end