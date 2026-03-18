function [burnBoxes, stainBoxes, numBurns, numStains] = detect_BurnsAndStains(img, detectBurns, detectStains)

    % Resize image and extract glove mask
    [filledMask, scaleFactor, img, ~] = glovePreprocess(img);

    % Convert to HSV for colour-based analysis
    hsv = rgb2hsv(img);
    H = hsv(:,:,1); S = hsv(:,:,2); V = hsv(:,:,3);

    % Estimate expected glove brightness — used by both burn and stain detection
    brightnessFilter = fspecial('gaussian', 301, 100);
    V_local          = imfilter(V, brightnessFilter, 'replicate');
    darkDrop         = V_local - V;

    burnMask  = false(size(filledMask));
    stainMask = false(size(filledMask));

    if detectBurns
        % Get glove base hue from neutral glove pixels (low sat, not dark)
        gloveHuePixels = H(filledMask & S < 0.20 & V > 0.35);
        if numel(gloveHuePixels) > 100
            baseHue = median(gloveHuePixels);
        else
            baseHue = 0.14;
        end

        % How far each pixel's hue is from the glove's own colour
        hueFromGlove = min(abs(H - baseHue), 1 - abs(H - baseHue));

        % Burn candidate = darker than surrounding glove AND hue stays near glove colour
        burnMask = darkDrop > 0.15 & hueFromGlove < 0.08 & filledMask;

        burnMaskCandidate = burnMask;

        % Remove noise and thin lines
        burnMask = imopen(burnMask,  strel('disk', 4));
        burnMask = imclose(burnMask, strel('disk', 5));
        burnMask = imfill(burnMask,  'holes');
        burnMask = bwareaopen(burnMask, 400);

        % Remove elongated shapes — keeps only compact burn-like blobs
        burnRegions = regionprops(burnMask, 'PixelIdxList', 'Eccentricity', 'Solidity');
        burnMask    = false(size(burnMask));
        for idx = 1:length(burnRegions)
            if burnRegions(idx).Eccentricity < 0.92 && burnRegions(idx).Solidity > 0.35
                burnMask(burnRegions(idx).PixelIdxList) = true;
            end
        end
    end

    if detectStains
        % Large Gaussian filter estimates local glove colour at every pixel
        hueBlurFilter   = fspecial('gaussian', 201, 60);
        filledMask      = imerode(filledMask, strel('disk', 10));
        gloveMaskDouble = double(filledMask);

        normFactor = imfilter(gloveMaskDouble, hueBlurFilter, 'replicate');
        H_local    = imfilter(H .* gloveMaskDouble, hueBlurFilter, 'replicate');
        H_local(filledMask) = H_local(filledMask) ./ normFactor(filledMask);

        % How far each pixel's hue is from the local glove colour
        hueShift = min(abs(H - H_local), 1 - abs(H - H_local));

        % Compute detection threshold from clean glove pixels only
        cleanGloveVals = hueShift(filledMask & S < 0.20 & V > 0.25);
        hueThreshold   = max(0.06, min(0.14, median(cleanGloveVals) + 2.0*std(cleanGloveVals)));

        % Stain candidate = hue shifted from glove colour + has colour + not black
        stainMask = filledMask & hueShift > hueThreshold & S > 0.12 & V > 0.15;

        % Remove burn-like regions — dark regions with no hue shift are burns not stains
        stainMask = stainMask & ~(darkDrop > 0.15 & hueShift < 0.08);

        stainMaskCandidate = stainMask;

        % Remove noise
        stainMask = imopen(stainMask,  strel('disk', 2));
        stainMask = imclose(stainMask, strel('disk', 5));
        stainMask = imfill(stainMask,  'holes');
        stainMask = bwareaopen(stainMask, 40);

        % Merge nearby fragments from sparse marker strokes
        bridgeElement = strel('disk', 12);
        stainMask     = imdilate(stainMask, bridgeElement);
        stainMask     = imerode(stainMask,  bridgeElement);
        stainMask     = bwareaopen(stainMask, 80);
    end

    % Get bounding boxes from each mask, filter by area
    burnBoxes  = extractBoxes(burnMask);
    stainBoxes = extractBoxes(stainMask);

    % Scale boxes back to original image size
    numBurns  = size(burnBoxes,1);
    numStains = size(stainBoxes,1);


    % --- Debug plots (comment out when not needed) ---

    % Burn pipeline
    figure('Name','Burn Pipeline','NumberTitle','off','Units','normalized','Position',[0.05 0.05 0.90 0.85]);

    subplot(2,4,1); imshow(img);
    title('1. Original');

    subplot(2,4,2); imshow(filledMask);
    title('2. Glove mask');

    subplot(2,4,3);
    maskedImg = img;
    maskedImg(repmat(~filledMask,[1 1 3])) = 0;
    imshow(maskedImg);
    title('3. Glove only');

    subplot(2,4,4); imagesc(V_local .* double(filledMask)); 
    colormap(subplot(2,4,4),'parula'); colorbar;
    title('4. V\_local');

    subplot(2,4,5); imagesc(darkDrop .* double(filledMask)); 
    colormap(subplot(2,4,5),'hot'); colorbar;
    title('5. darkDrop');

    subplot(2,4,6); imshow(burnMaskCandidate);
    title('6. Burn candidate');

    subplot(2,4,7); imshow(burnMask);
    title('7. Burn mask cleaned');

    subplot(2,4,8); imshow(img); hold on;
    for i = 1:size(burnBoxes,1)
        bb = burnBoxes(i,:);
        rectangle('Position',bb,'EdgeColor','r','LineWidth',2);
        text(bb(1),bb(2)-5,sprintf('Burn %d',i),'Color','r','FontSize',8,'FontWeight','bold');
    end
    hold off;
    title(sprintf('8. Burns: %d', numBurns));

    % Stain pipeline
    figure('Name','Stain Pipeline','NumberTitle','off','Units','normalized','Position',[0.05 0.05 0.90 0.85]);

    subplot(2,4,1); imshow(img);
    title('1. Original');

    subplot(2,4,2); imshow(filledMask);
    title('2. Glove mask');

    subplot(2,4,3);
    maskedImg = img;
    maskedImg(repmat(~filledMask,[1 1 3])) = 0;
    imshow(maskedImg);
    title('3. Glove only');

    subplot(2,4,4); imagesc(H_local .* double(filledMask)); 
    colormap(subplot(2,4,4),'parula'); colorbar;
    title('4. H\_local');

    subplot(2,4,5); imagesc(hueShift .* double(filledMask)); 
    colormap(subplot(2,4,5),'hot'); colorbar;
    title('5. hueShift');

    subplot(2,4,6); imshow(stainMaskCandidate);
    title('6. Stain candidate');

    subplot(2,4,7); imshow(stainMask);
    title('7. Stain mask cleaned');

    subplot(2,4,8); imshow(img); hold on;
    for i = 1:size(stainBoxes,1)
        bb = stainBoxes(i,:);
        rectangle('Position',bb,'EdgeColor','b','LineWidth',2);
        text(bb(1),bb(2)-5,sprintf('Stain %d',i),'Color','b','FontSize',8,'FontWeight','bold');
    end
    hold off;
    title(sprintf('8. Stains: %d', numStains));

    burnBoxes  = burnBoxes  * scaleFactor;
    stainBoxes = stainBoxes * scaleFactor;
end


function boxes = extractBoxes(mask)
    boxes = [];
    if ~any(mask(:)), return; end
    regions = regionprops(mask, 'BoundingBox','Area');
    for idx = 1:length(regions)
        if regions(idx).Area > 80
            boxes = [boxes; regions(idx).BoundingBox];
        end
    end
end