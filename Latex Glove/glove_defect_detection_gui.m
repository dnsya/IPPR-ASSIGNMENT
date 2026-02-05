function glove_defect_detection_gui
% GLOVE_DEFECT_DETECTION_GUI Main GUI for glove defect detection system
%
% - Import glove images
% - Detect multiple types of defects: holes (body), fingertip holes, stains
% - Visualize detection results
% - View detection statistics

    clc;
    close all;
    
    % Create main figure
    fig = figure('Name', 'Glove Defect Detection System', ...
                 'NumberTitle', 'off', ...
                 'Position', [100 100 1200 650], ...
                 'Resize', 'off', ...
                 'MenuBar', 'none', ...
                 'Color', [0.94 0.94 0.94]);
    
    % Create axes for image display
    axOriginal = axes('Parent', fig, ...
                      'Units', 'pixels', ...
                      'Position', [30 250 400 350], ...
                      'Box', 'on');
    title(axOriginal, 'Original Image', 'FontSize', 12, 'FontWeight', 'bold');
    axis off;
    
    axResult = axes('Parent', fig, ...
                    'Units', 'pixels', ...
                    'Position', [470 250 400 350], ...
                    'Box', 'on');
    title(axResult, 'Detection Result', 'FontSize', 12, 'FontWeight', 'bold');
    axis off;
    
    % Control panel background
    uipanel('Parent', fig, ...
            'Units', 'pixels', ...
            'Position', [910 250 260 350], ...
            'Title', 'Controls', ...
            'FontSize', 11, ...
            'FontWeight', 'bold', ...
            'BackgroundColor', [0.94 0.94 0.94]);
    
    % Import Image button
    btnLoad = uicontrol('Style', 'pushbutton', ...
                        'String', 'Import Image', ...
                        'Position', [930 530 220 50], ...
                        'FontSize', 12, ...
                        'FontWeight', 'bold', ...
                        'BackgroundColor', [0.3 0.6 0.9], ...
                        'ForegroundColor', 'white', ...
                        'Callback', @loadImage);
    
    % Detect All Defects button
    btnDetectAll = uicontrol('Style', 'pushbutton', ...
                             'String', 'Detect All Defects', ...
                             'Position', [930 460 220 50], ...
                             'FontSize', 12, ...
                             'FontWeight', 'bold', ...
                             'BackgroundColor', [0.2 0.7 0.3], ...
                             'ForegroundColor', 'white', ...
                             'Callback', @detectAllDefects);
    
    % Individual detection buttons
    btnDetectHoles = uicontrol('Style', 'pushbutton', ...
                               'String', 'Detect Holes', ...
                               'Position', [930 400 220 40], ...
                               'FontSize', 11, ...
                               'BackgroundColor', [0.9 0.5 0.5], ...
                               'Callback', @detectHolesOnly);
    
    btnDetectContamination = uicontrol('Style', 'pushbutton', ...
                             'String', 'Detect Contamination', ...
                             'Position', [930 350 220 40], ...
                             'FontSize', 11, ...
                             'BackgroundColor', [0.5 0.5 0.9], ...
                             'ForegroundColor', 'white', ...
                             'Callback', @detectContaminationOnly);
    
    btnDetectStain = uicontrol('Style', 'pushbutton', ...
                               'String', 'Detect Stains', ...
                               'Position', [930 300 220 40], ...
                               'FontSize', 11, ...
                               'BackgroundColor', [0.9 0.7 0.2], ...
                               'Callback', @detectStainOnly);
    
    % Clear button
    btnClear = uicontrol('Style', 'pushbutton', ...
                         'String', 'Clear', ...
                         'Position', [930 270 220 25], ...
                         'FontSize', 10, ...
                         'BackgroundColor', [0.95 0.95 0.95], ...
                         'Callback', @clearDisplay);
    
    % Results panel
    resultPanel = uipanel('Parent', fig, ...
                          'Units', 'pixels', ...
                          'Position', [30 30 1140 200], ...
                          'Title', 'Detection Results', ...
                          'FontSize', 11, ...
                          'FontWeight', 'bold', ...
                          'BackgroundColor', 'white');
    
    % Results text box - LISTBOX for scrolling
    txtResults = uicontrol('Parent', resultPanel, ...
                           'Style', 'listbox', ...
                           'String', {'No detection performed yet.'}, ...
                           'Position', [10 10 1110 170], ...
                           'FontSize', 10, ...
                           'FontName', 'FixedWidth', ...
                           'BackgroundColor', 'white', ...
                           'Max', 2, ...
                           'Min', 0);
    
    % Initialize handles structure
    handles.image = [];
    handles.gloveMask = [];
    handles.fileName = '';
    guidata(fig, handles);
    
    %% Callback Functions
    
    function loadImage(~, ~)
        handles = guidata(fig);
        
        [fileName, pathName] = uigetfile(...
            {'*.jpg;*.jpeg;*.png;*.bmp', 'Image Files (*.jpg, *.jpeg, *.png, *.bmp)'; ...
             '*.*', 'All Files (*.*)'}, ...
            'Select a glove image');
        
        if isequal(fileName, 0)
            return; % User canceled
        end
        
        % Read image
        handles.image = imread(fullfile(pathName, fileName));
        handles.fileName = fileName;
        guidata(fig, handles);
        
        % Display original image
        axes(axOriginal);
        imshow(handles.image);
        title(axOriginal, ['Original: ' fileName], 'FontSize', 12, 'FontWeight', 'bold', 'Interpreter', 'none');
        
        % Clear result display
        axes(axResult);
        cla;
        title(axResult, 'Detection Result', 'FontSize', 12, 'FontWeight', 'bold');
        axis off;
        
        set(txtResults, 'String', 'Image loaded successfully. Click "Detect All Defects" to analyze.');
    end
    
    function detectAllDefects(~, ~)
        handles = guidata(fig);
        
        if isempty(handles.image)
            errordlg('Please load an image first.', 'No Image');
            return;
        end
        
        set(txtResults, 'String', 'Processing... Please wait.');
        drawnow;
        
        I = handles.image;
        
        % Segment glove using HSV
        gloveMask = segment_glove_hsv(I);
        handles.gloveMask = gloveMask;
        guidata(fig, handles);
        
        % Detect all defect types
        [holeMask, holeStats, numHoles] = detect_holes(I, gloveMask);
        [contamMask, contamStats, numContam] = detect_contamination(I, gloveMask);
        [stainMask, stainStats, numStains] = detect_stains(I, gloveMask);
        
        % Display results
        axes(axResult);
        imshow(I);
        hold on;
        
        % Draw holes (red)
        for i = 1:length(holeStats)
            rectangle('Position', holeStats(i).BoundingBox, ...
                      'EdgeColor', 'r', 'LineWidth', 2);
            plot(holeStats(i).Centroid(1), holeStats(i).Centroid(2), ...
                 'r+', 'MarkerSize', 12, 'LineWidth', 2);
            text(holeStats(i).BoundingBox(1), holeStats(i).BoundingBox(2)-10, ...
                 'HOLE', 'Color', 'r', 'FontSize', 9, 'FontWeight', 'bold', ...
                 'BackgroundColor', 'white');
        end
        
        % Draw contamination (blue) with LARGER markers
        for i = 1:length(contamStats)
            % Draw bounding box
            rectangle('Position', contamStats(i).BoundingBox, ...
                      'EdgeColor', [0.2 0.2 0.9], 'LineWidth', 3);
            
            % Draw large X marker covering the contamination area
            bbox = contamStats(i).BoundingBox;
            x1 = bbox(1);
            y1 = bbox(2);
            x2 = bbox(1) + bbox(3);
            y2 = bbox(2) + bbox(4);
            
            % Draw diagonal cross (X)
            plot([x1 x2], [y1 y2], 'Color', [1 0 0], 'LineWidth', 3);  % Red X
            plot([x2 x1], [y1 y2], 'Color', [1 0 0], 'LineWidth', 3);  % Red X
            
            % Label
            text(bbox(1), bbox(2)-10, ...
                 'CONTAMINATION', 'Color', 'r', 'FontSize', 10, 'FontWeight', 'bold', ...
                 'BackgroundColor', 'white');
        end
        
        % Draw stains (yellow)
        for i = 1:length(stainStats)
            rectangle('Position', stainStats(i).BoundingBox, ...
                      'EdgeColor', [1 0.8 0], 'LineWidth', 2);
            plot(stainStats(i).Centroid(1), stainStats(i).Centroid(2), ...
                 'y+', 'MarkerSize', 12, 'LineWidth', 2);
            text(stainStats(i).BoundingBox(1), stainStats(i).BoundingBox(2)-10, ...
                 'STAIN', 'Color', [0.9 0.7 0], 'FontSize', 9, 'FontWeight', 'bold', ...
                 'BackgroundColor', 'white');
        end
        
        hold off;
        title(axResult, 'All Defects Detected', 'FontSize', 12, 'FontWeight', 'bold');
        
        % Update results text - LISTBOX FORMAT
        totalDefects = numHoles + numContam + numStains;  
        
        
        resultLines = {
            'DETECTION SUMMARY';
            '=====================================';
            '';
            sprintf('Total Defects Found: %d', totalDefects);
            '';
            'Breakdown:';
            sprintf('  • Holes: %d', numHoles);
            sprintf('  • Surface Contamination: %d', numContam);
            sprintf('  • Stains: %d', numStains);
            '';
            sprintf('Status: %s', getQualityStatus(totalDefects));
            '';
            'Legend:';
            '  Red = Holes';
            '  Blue = Contamination';
            '  Yellow = Stains'
        };
     
        set(txtResults, 'String', resultLines);
    end
    
    function detectHolesOnly(~, ~)
        handles = guidata(fig);
        
        if isempty(handles.image)
            errordlg('Please load an image first.', 'No Image');
            return;
        end
        
        I = handles.image;
        gloveMask = segment_glove_hsv(I);
        
        [holeMask, holeStats, numHoles] = detect_holes(I, gloveMask);
        
        displaySingleDefect(I, holeStats, 'HOLE', 'r', 'Holes Detected');
        
        set(txtResults, 'String', sprintf('Hole Detection:\n%d hole(s) found in glove body.', numHoles));
    end
    
    function detectStainOnly(~, ~)
        handles = guidata(fig);
        
        if isempty(handles.image)
            errordlg('Please load an image first.', 'No Image');
            return;
        end
        
        I = handles.image;
        gloveMask = segment_glove_hsv(I);
        
        [stainMask, stainStats, numStains] = detect_stains(I, gloveMask);
        
        displaySingleDefect(I, stainStats, 'STAIN', [1 0.8 0], 'Stains Detected');
        
        set(txtResults, 'String', sprintf('Stain Detection:\n%d stain(s) found.', numStains));
    end

    function detectContaminationOnly(~, ~)
        handles = guidata(fig);
    
        if isempty(handles.image)
            errordlg('Please load an image first.', 'No Image');
            return;
        end
    
        I = handles.image;
    
        % Segment glove
        gloveMask = segment_glove_hsv(I);
    
        % Detect contamination
        [contamMask, contamStats, numContam] = detect_contamination(I, gloveMask);
    
        % Display result
        axes(axResult);
        imshow(I);
        hold on;
    
        for i = 1:length(contamStats)
            % Draw bounding box
            rectangle('Position', contamStats(i).BoundingBox, ...
                       'EdgeColor', [1 0 0], 'LineWidth', 1, 'LineStyle', '--');
      
            
            % Label
            text(contamStats(i).BoundingBox(1), ...
                 contamStats(i).BoundingBox(2)-12, ...
                 'SURFACE CONTAMINATION', ...
                 'Color', 'r', 'FontSize', 10, 'FontWeight', 'bold');
        end
    
        hold off;
        title(axResult, 'Surface Contamination Detected');
    
        set(txtResults, 'String', ...
            sprintf('Surface Contamination Detection:\n%d object(s) detected.', numContam));
    end

    
    function displaySingleDefect(I, stats, label, color, titleStr)
        axes(axResult);
        imshow(I);
        hold on;
        
        for i = 1:length(stats)
            %rectangle('Position', stats(i).BoundingBox, ...
            % 'EdgeColor', color, 'LineWidth', 2);
            plot(stats(i).Centroid(1), stats(i).Centroid(2), ...
                 '+', 'Color', color, 'MarkerSize', 14, 'LineWidth', 1);
            text(stats(i).Centroid(1) + 20, ...
                 stats(i).Centroid(2) - 20, ...
                 label, ...
                 'Color', color, ...
                 'FontSize', 9, ...
                 'FontWeight', 'bold', ...
                 'Margin', 2);
        end
        
        hold off;
        title(axResult, titleStr, 'FontSize', 12, 'FontWeight', 'bold');
    end
    
    function clearDisplay(~, ~)
        axes(axOriginal);
        cla;
        title(axOriginal, 'Original Image', 'FontSize', 12, 'FontWeight', 'bold');
        axis off;
        
        axes(axResult);
        cla;
        title(axResult, 'Detection Result', 'FontSize', 12, 'FontWeight', 'bold');
        axis off;
        
        set(txtResults, 'String', 'Display cleared. Load an image to begin.');
        
        handles = guidata(fig);
        handles.image = [];
        handles.gloveMask = [];
        handles.fileName = '';
        guidata(fig, handles);
    end
    
    function status = getQualityStatus(totalDefects)
        if totalDefects == 0
            status = '✓ PASS - No defects detected';
        elseif totalDefects <= 2
            status = '⚠ WARNING - Minor defects detected';
        else
            status = '✗ FAIL - Multiple defects detected';
        end
    end
end