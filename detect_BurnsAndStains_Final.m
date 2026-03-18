function [burnBoxes, stainBoxes, numBurns, numStains] = detect_BurnsAndStains(img, detectBurns, detectStains)

    [filledMask, scaleFactor, img, grayImg] = glovePreprocess(img);

    hsv = rgb2hsv(img);
    H = hsv(:,:,1); S = hsv(:,:,2); V = hsv(:,:,3);

    glove_interior = imerode(filledMask, strel('disk', 10));
    V_local  = computeVLocal(V, filledMask);
    darkDrop = V_local - V;
    gloveH   = H(filledMask & S < 0.20 & V > 0.35);
    baseHue  = ternary(numel(gloveH) > 100, median(gloveH), 0.14);
    baseDev  = min(abs(H - baseHue), 1 - abs(H - baseHue));

    burnMask  = false(size(filledMask));
    stainMask = false(size(filledMask));

    if detectBurns
        burnMask = darkDrop > 0.15 & baseDev < 0.08 & glove_interior;
        burnMask = imopen(burnMask,  strel('disk', 3));
        burnMask = imclose(burnMask, strel('disk', 5));
        burnMask = imfill(burnMask,  'holes');
        burnMask = bwareaopen(burnMask, 150);
        burnMask = imopen(burnMask,  strel('disk', 6));
        burnMask = imfill(burnMask,  'holes');
        burnMask = bwareaopen(burnMask, 400);
    end

    if detectStains
        k       = fspecial('gaussian', 201, 60);
        maskD   = double(filledMask);
        H_local = imfilter(H.*maskD, k, 'replicate') ./ ...
                  (imfilter(maskD,   k, 'replicate') + 1e-6);
        hueDev  = min(abs(H - H_local), 1 - abs(H - H_local));
        cleanVals = hueDev(filledMask & S < 0.20 & V > 0.25);
        hueThresh = max(0.06, min(0.14, median(cleanVals) + 2.0*std(cleanVals)));
        stainMask = glove_interior & hueDev > hueThresh & S > 0.12 & V > 0.15;
        stainMask = stainMask & ~(darkDrop > 0.15 & hueDev < 0.08);
        stainMask = imopen(stainMask,  strel('disk', 2));
        stainMask = imclose(stainMask, strel('disk', 5));
        stainMask = imfill(stainMask,  'holes');
        stainMask = bwareaopen(stainMask, 40);
        bridge    = strel('disk', 12);
        stainMask = imdilate(stainMask, bridge);
        stainMask = imerode(stainMask,  bridge);
        stainMask = bwareaopen(stainMask, 80);
    end

    burnBoxes  = extractBoxes(burnMask,  'burn');
    stainBoxes = extractBoxes(stainMask, 'stain');

    if ~isempty(burnBoxes) && ~isempty(stainBoxes)
        keep = true(size(stainBoxes,1), 1);
        for s = 1:size(stainBoxes,1)
            sc = stainBoxes(s,1:2) + stainBoxes(s,3:4)/2;
            for b = 1:size(burnBoxes,1)
                % Compute overlap between stain and burn box
                ix  = max(0, min(stainBoxes(s,1)+stainBoxes(s,3), burnBoxes(b,1)+burnBoxes(b,3)) - max(stainBoxes(s,1),burnBoxes(b,1)));
                iy  = max(0, min(stainBoxes(s,2)+stainBoxes(s,4), burnBoxes(b,2)+burnBoxes(b,4)) - max(stainBoxes(s,2),burnBoxes(b,2)));
                overlap = (ix*iy) / (stainBoxes(s,3)*stainBoxes(s,4) + burnBoxes(b,3)*burnBoxes(b,4) - ix*iy + 1e-6);
    
                if overlap > 0.20 || ...
                   (sc(1) > burnBoxes(b,1) && sc(1) < burnBoxes(b,1)+burnBoxes(b,3) && ...
                    sc(2) > burnBoxes(b,2) && sc(2) < burnBoxes(b,2)+burnBoxes(b,4))
                    keep(s) = false;
                end
            end
        end
        stainBoxes = stainBoxes(keep,:);
    end

    burnBoxes  = burnBoxes  * scaleFactor;
    stainBoxes = stainBoxes * scaleFactor;
    numBurns   = size(burnBoxes,1);
    numStains  = size(stainBoxes,1);

    debugPlot(img, filledMask, glove_interior, burnMask, stainMask, ...
              burnBoxes, stainBoxes, numBurns, numStains);
end

function V_local = computeVLocal(V, filledMask)
    brightMask = V > 0.60 & filledMask;
    k   = fspecial('gaussian', 151, 50);
    num = imfilter(V .* double(brightMask), k, 'replicate');
    den = imfilter(double(brightMask),       k, 'replicate') + 1e-6;
    V_local = num ./ den;
end

function boxes = extractBoxes(mask, mode)
    boxes = [];
    if ~any(mask(:)), return; end
    props = regionprops(mask, 'BoundingBox', 'Area', 'Eccentricity', 'Solidity');
    for k = 1:length(props)
        a = props(k).Area; ecc = props(k).Eccentricity;
        sol = props(k).Solidity; bb = props(k).BoundingBox;
        if strcmp(mode,'burn')
            if a > 500  && a < 50000 && ecc < 0.92 && sol > 0.35, boxes = [boxes; bb]; end
        else
            if a > 80   && a < 30000 && ecc < 0.92 && sol > 0.40, boxes = [boxes; bb]; end
        end
    end
end

function debugPlot(img, filledMask, glove_interior, burnMask, stainMask, ...
                   burnBoxes, stainBoxes, numBurns, numStains)
    figure('Name','Debug','NumberTitle','off', ...
           'Units','normalized','Position',[0.05 0.05 0.90 0.85]);
    subplot(2,3,1); imshow(img);            title('1. Original');
    subplot(2,3,2); imshow(filledMask);     title('2. Glove mask');
    subplot(2,3,3); imshow(glove_interior); title('3. Glove interior');
    subplot(2,3,4); imshow(burnMask);       title('4. Burn mask');
    subplot(2,3,5); imshow(stainMask);      title('5. Stain mask');
    subplot(2,3,6); imshow(img); hold on;
    for i = 1:size(burnBoxes,1)
        bb = burnBoxes(i,:);
        rectangle('Position',bb,'EdgeColor','r','LineWidth',2);
        text(bb(1),bb(2)-5,sprintf('Burn %d',i),'Color','r','FontSize',8,'FontWeight','bold');
    end
    for i = 1:size(stainBoxes,1)
        bb = stainBoxes(i,:);
        rectangle('Position',bb,'EdgeColor','b','LineWidth',2);
        text(bb(1),bb(2)-5,sprintf('Stain %d',i),'Color','b','FontSize',8,'FontWeight','bold');
    end
    hold off;
    title(sprintf('Burns: %d (red)   Stains: %d (blue)', numBurns, numStains));
end

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end