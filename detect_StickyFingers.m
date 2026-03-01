function [fusedBoxes, numFused] = detect_StickyFingers(img)
    % Shared preprocessing (resize, scale factor, grayscale, glove mask)
    [filledMask, scaleFactor, imgResized, ~] = glovePreprocess(img);
    
    % Get glove orientation
    propsFilledMask = regionprops(filledMask, 'Orientation');
    imgOrientation = abs(propsFilledMask.Orientation);
    
    % Anatomical separation - palm
    se_palm = strel('disk', 150);
    palmImg = imopen(filledMask, se_palm);
    
    % Finger area by subtraction
    finger = imsubtract(filledMask, palmImg);
    finger = bwareaopen(finger, 20000);
    
    % Refine fingers
    seOpen = strel('disk', 15);
    fingerMask = imopen(finger, seOpen);
    fingerMask = bwareaopen(fingerMask, 10000);
    
    % Analysis
    props = regionprops(fingerMask, 'BoundingBox', 'Area', 'Orientation', ...
        'MaxFeretProperties', 'MinFeretProperties');
    widths = [];
    fusedBoxes = [];
    
    if ~isempty(props)
        % Find finger regions orientation and width 
        for k = 1:length(props) 
            orientation = abs(props(k).Orientation); 
            orienDiff = abs(imgOrientation - orientation); 
            % If finger is angled differently from glove (>70 deg), use MaxFeret
            if orienDiff < 70 
                w = props(k).MinFeretDiameter; 
            else 
                w = props(k).MaxFeretDiameter; 
            end 
            widths = [widths; w]; 
        end 

        % Detect fused fingers
        for k = 1:length(widths)
            % If finger is 1.8x wider than the thinnest, it is fused
            if widths(k) / min(widths) >= 1.8
                fusedBoxes = [fusedBoxes; props(k).BoundingBox * scaleFactor];
            end
        end
    end
    numFused = size(fusedBoxes, 1);
end