function defects = detect_stains(img)
    defects = [];
    counter = 1;
    
    gray = rgb2gray(img);
    filtered_image = medfilt2(gray, [3,3]);
    
    % Invert the image to better spot the stain
    binary_image = imbinarize(filtered_image, 0.45);
    inverted_binary_image = ~binary_image;
    inverted_binary_image = imopen(inverted_binary_image, strel('disk',3));
    
    % Fills the holes and keep the largest region of the glove
    filled_image = imfill(inverted_binary_image, 'holes');
    glove_mask = bwareafilt(filled_image, 1);
    glove_mask = imdilate(glove_mask, strel('disk',1));
    
    % find the glove edge and create a 10 pixel buffer zone around it
    glove_edge = bwperim(glove_mask);
    glove_edge_buffer = imdilate(glove_edge, strel('disk', 10));
    glove_interior = glove_mask & ~glove_edge_buffer;
    
    % Find the bright areas and clean up the region
    defect_mask = imopen(inverted_binary_image, strel(ones(5)));
    light_stain_mask = glove_mask & ~defect_mask;
    light_stain_mask = imopen(light_stain_mask, strel('square',2));
    light_stain_mask = light_stain_mask & glove_interior;
    
    % Extract the hsv values from the image
    hsv_image = rgb2hsv(img);
    hue = hsv_image(:,:,1);
    sat = hsv_image(:,:,2);
    val = hsv_image(:,:,3);
    
    % detect the bright, colourful regions and calculate the gradient magnitude
    is_bright = val > 0.75;
    is_colorful = sat > 0.2;
    edge_strength = imgradient(gray);
    high_edge = edge_strength > 0.05;
    reflection_mask = is_bright & ~is_colorful & ~high_edge;
    light_stain_mask(reflection_mask) = 0;
    
    % Find the more common stain (red & yellow) that are not that bright
    red_hue = (hue < 0.15) | (hue > 0.85);
    yellow_hue = (hue > 0.08) & (hue < 0.25);
    has_color = sat > 0.25;
    appropriate_brightness = val < 0.6;
    dark_stain_mask = (red_hue | yellow_hue) & has_color & appropriate_brightness;
    dark_stain_mask = dark_stain_mask & glove_interior;
    dark_stain_mask = imopen(dark_stain_mask, strel('disk',1));
    dark_stain_mask = bwareaopen(dark_stain_mask, 15);
    
    % Detect the skin color regions to avoid being identified as stain
    % Same as detect_holes.m btw
    skin_hue = (hue < 0.15) | (hue > 0.85);  % Reddish/yellowish
    skin_sat = sat < 0.35;  % Low saturation
    skin_val = (val > 0.4) & (val < 0.95);  % Not too dark, not too bright
    skin_mask = skin_hue & skin_sat & skin_val;
    skin_mask = bwareaopen(skin_mask, 300);
    
    % Remove skin regions from both stain masks
    light_stain_mask = light_stain_mask & ~skin_mask;
    dark_stain_mask = dark_stain_mask & ~skin_mask;
    
    % Combine bright and dark stains
    combined_stain_mask = light_stain_mask | dark_stain_mask;
    
    % Find the connected components and calculate the eccentricity (elongation)
    connected_components = bwconncomp(combined_stain_mask);
    stain_props = regionprops(connected_components, 'BoundingBox','Area', ...
        'Eccentricity');
        
    for k = 1:connected_components.NumObjects
        area = stain_props(k).Area;
        ecc = stain_props(k).Eccentricity;
        bbox = stain_props(k).BoundingBox;
            
        if area > 400 && area < 20000 && ecc < 0.8
            d.type = ['Stain ' int2str(counter)];
            d.bbox = bbox;
            defects = [defects; d];
            counter = counter + 1;
        end
    end

    debug_mode = true;  % Change to false to disable debug views

    if debug_mode
        figure('Name', 'Stain Detection Debug', 'Position', [50, 100, 1100, 700]);
        
        % Step 1: Original Image
        subplot(3, 3, 1);
        imshow(img);
        title('1. Original Image', 'FontSize', 10);
        
        % Step 2: Inverted binary
        subplot(3, 3, 2);
        imshow(inverted_binary_image);
        title('2. Inverted Binary', 'FontSize', 10);
        xlabel('Threshold at 0.45');
        
        % Step 3: Glove mask
        subplot(3, 3, 3);
        imshow(glove_mask);
        title('3. Glove Mask', 'FontSize', 10);
        xlabel('Largest region kept');
        
        % Step 4: Glove interior
        subplot(3, 3, 4);
        imshow(glove_interior);
        title('4. Glove Interior', 'FontSize', 10);
        xlabel('Removed edge buffer');
        
        % Step 5: Light stain mask
        subplot(3, 3, 5);
        imshow(light_stain_mask);
        title('5. Light Stain Candidates', 'FontSize', 10);
        
        % Step 6: Dark stain mask
        subplot(3, 3, 6);
        imshow(dark_stain_mask);
        title('6. Dark Stain Candidates', 'FontSize', 10);
        xlabel('Red/Yellow hue regions');
        
        % Step 7: Skin mask (to exclude)
        subplot(3, 3, 7);
        imshow(skin_mask);
        title('7. Skin Mask (Excluded)', 'FontSize', 10);
        
        % Step 8: Combined stain mask
        subplot(3, 3, 8);
        imshow(combined_stain_mask);
        title('8. Combined Stains', 'FontSize', 10);
        xlabel('Light | Dark - Skin');
        
        % Step 9: Final overlay
        subplot(3, 3, 9);
        imshow(img);
        hold on;
        
        % Get properties and draw rectangles for visualization
        connected_components = bwconncomp(combined_stain_mask);
        stain_props = regionprops(connected_components, 'BoundingBox', 'Area', 'Eccentricity');
        
        for k = 1:connected_components.NumObjects
            area = stain_props(k).Area;
            ecc = stain_props(k).Eccentricity;
            
            if area > 400 && area < 20000 && ecc < 0.8
                rectangle('Position', stain_props(k).BoundingBox, ...
                         'EdgeColor', 'y', 'LineWidth', 2);
            end
        end
        hold off;
        title('9. Detected Stains', 'FontSize', 10);
        
        sgtitle('Stain Detection - Step by Step Process', 'FontSize', 14, 'FontWeight', 'bold');
    end
end