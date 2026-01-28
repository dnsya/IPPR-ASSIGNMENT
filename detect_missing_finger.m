function defects = detect_missing_finger(img)
    defects = [];
    counter = 1;

    gray = rgb2gray(img);
    blurred = imgaussfilt(gray, 4);

    % Creates 2 masks for comparison
    glove_mask = ~imbinarize(blurred, 0.65);
    finger_mask   = ~imbinarize(blurred, 0.40);

    % Get a clearer glove outline
    glove_filled = imfill(glove_mask, 'holes');
    glove_filled = imopen(glove_filled, strel('disk',10));
    glove_filled = bwareaopen(glove_filled, 1000);
    glove_filled = imerode(glove_filled, strel('disk',15));

    % Find the perimeter of the glove and create a 15 pixel buffer around
    glove_edge = bwperim(glove_filled);
    edge_buffer = imdilate(glove_edge, strel('disk',15));

    % Clean the defect mask
    finger_mask = imopen(finger_mask, strel(ones(5)));

    % Find the regions that are in the glove but not in the defect masks
    missing_mask = glove_filled & ~finger_mask;

    % Remove the noise
    missing_mask = imopen(missing_mask, strel('square',2));
    missing_mask = imerode(missing_mask, strel('disk',2));

    % Finds the connected component in the missing mask
    connected_components = bwconncomp(missing_mask);
    finger_props = regionprops(connected_components, ...
        'BoundingBox','Area','MajorAxisLength','MinorAxisLength');

    % Fingertip region (top of glove)
    bbox = regionprops(glove_filled, 'BoundingBox');
    gbox = bbox(1).BoundingBox;
    fingertip_limit = gbox(2) + 0.8 * gbox(4);

    % create a masks that only in the top 80% of the glove
    fingertip_region = false(size(glove_filled));
    fingertip_region(1:round(fingertip_limit), :) = true;

    for k = 1:connected_components.NumObjects
        area = finger_props(k).Area;
        aspect_ratio = finger_props(k).MajorAxisLength / ...
                       max(finger_props(k).MinorAxisLength,1);

        candidate = false(size(missing_mask));
        candidate(connected_components.PixelIdxList{k}) = true;

        % Check if the candidate is touching the edge and in the fingertip
        % area
        touches_edge = any(candidate & edge_buffer & fingertip_region, 'all');

        % Ensure the defect is finger like with the aspect ratio
        if area > 2000 && area < 20000 && ...
           touches_edge && aspect_ratio <= 5

            d.type = ['Missing Finger ' int2str(counter)];
            d.bbox = finger_props(k).BoundingBox;
            defects = [defects; d];
            counter = counter + 1;
        end
    end
end