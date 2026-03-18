function [fusedBoxes, numFused] = detect_StickyFingers(img)
    showDebug = true;

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

    % --- Debug plot (comment out when not needed) ---
    if showDebug
        figure('Name','Fused Finger Detection','NumberTitle','off','Units','normalized','Position',[0.05 0.05 0.90 0.85]);

        subplot(2,3,1); imshow(imgResized);
        title('1. Original');

        subplot(2,3,2); imshow(filledMask);
        title('2. Glove mask');

        subplot(2,3,3);
        maskedImg = imgResized;
        maskedImg(repmat(~filledMask,[1 1 3])) = 0;
        imshow(maskedImg);
        title('3. Glove only');

        subplot(2,3,4); imshow(palmImg);
        title('4. Palm mask');

        subplot(2,3,5); imshow(fingerMask);
        title('5. Finger mask');

        subplot(2,3,6); imshow(imgResized); hold on;
        for i = 1:size(fusedBoxes,1)
            bb = fusedBoxes(i,:) / scaleFactor;
            rectangle('Position',bb,'EdgeColor','r','LineWidth',2);
            text(bb(1),bb(2)-5,sprintf('Fused %d',i),'Color','r','FontSize',8,'FontWeight','bold');
        end
        hold off;
        title(sprintf('6. Fused fingers: %d', numFused));
    end
end