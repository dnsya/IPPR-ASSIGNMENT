function glove_defect_detection_gui
% GLOVE_DEFECT_DETECTION_GUI Main GUI for glove defect detection system
%
% - Import glove images
% - Detect multiple types of defects: tears (body defects), stains, contamination
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
                 'Color', [0.1 0.1 0.1]);
    
    % Create axes for image display
    axOriginal = axes('Parent', fig, ...
                      'Units', 'pixels', ...
                      'Position', [30 250 400 350], ...
                      'Box', 'on');
    title(axOriginal, 'Original Image', ...
          'FontSize', 12, ...
          'FontWeight', 'bold', ...
          'Color', 'white');
    axis off;
    
    axResult = axes('Parent', fig, ...
                    'Units', 'pixels', ...
                    'Position', [470 250 400 350], ...
                    'Box', 'on');
    title(axResult, 'Detection Result', ...
          'FontSize', 12, ...
          'FontWeight', 'bold', ...
          'Color', 'white');
    axis off;
    
    % Control panel background
    uipanel('Parent', fig, ...
            'Units', 'pixels', ...
            'Position', [910 250 260 350], ...
            'Title', 'Controls', ...
            'FontSize', 11, ...
            'FontWeight', 'bold', ...
            'BackgroundColor', [0.15 0.15 0.15],...
            'ForegroundColor', 'white')
    
    uicontrol('Style', 'pushbutton', ...
                        'String', 'RETURN', ...
                        'Position', [957 605 170 40], ...
                        'FontSize', 12, ...
                        'FontWeight', 'bold', ...
                        'BackgroundColor', [1, 0, 0], ...
                        'ForegroundColor', 'black', ...
                        'Callback', @loadImage);
    
    % Import Image button
    uicontrol('Style', 'pushbutton', ...
                        'String', 'Import Image', ...
                        'Position', [930 530 220 50], ...
                        'FontSize', 12, ...
                        'FontWeight', 'bold', ...
                        'BackgroundColor', [0.3 0.6 0.9], ...
                        'ForegroundColor', 'white', ...
                        'Callback', @loadImage);
    
    % Detect All Defects button
    uicontrol('Style', 'pushbutton', ...
                             'String', 'Detect All Defects', ...
                             'Position', [930 460 220 50], ...
                             'FontSize', 12, ...
                             'FontWeight', 'bold', ...
                             'BackgroundColor', [0.2 0.7 0.3], ...
                             'ForegroundColor', 'white', ...
                             'Callback', @detectAllDefects);
    
    % Individual detection buttons
    uicontrol('Style', 'pushbutton', ...
                               'String', 'Detect Tears', ...
                               'Position', [930 400 220 40], ...
                               'FontSize', 11, ...
                               'BackgroundColor', [0.9 0.5 0.5], ...
                               'ForegroundColor', 'white', ...
                               'Callback', @detectTearsOnly);
    
    uicontrol('Style', 'pushbutton', ...
                             'String', 'Detect Contamination', ...
                             'Position', [930 350 220 40], ...
                             'FontSize', 11, ...
                             'BackgroundColor', [0.5 0.5 0.9], ...
                             'ForegroundColor', 'white', ...
                             'Callback', @detectContaminationOnly);
    
    uicontrol('Style', 'pushbutton', ...
                               'String', 'Detect Stains', ...
                               'Position', [930 300 220 40], ...
                               'FontSize', 11, ...
                               'BackgroundColor', [0.9 0.7 0.2], ...
                               'ForegroundColor', 'white', ...
                               'Callback', @detectStainOnly);
    
    % Clear button
    uicontrol('Style', 'pushbutton', ...
                         'String', 'Clear', ...
                         'Position', [930 270 220 25], ...
                         'FontSize', 10, ...
                         'BackgroundColor', [0.95 0.95 0.95], ...
                         'ForegroundColor', 'black', ...
                         'Callback', @clearDisplay);
    
    % Results panel
    resultPanel = uipanel('Parent', fig, ...
                          'Units', 'pixels', ...
                          'Position', [30 30 1140 200], ...
                          'Title', 'Detection Results', ...
                          'FontSize', 11, ...
                          'FontWeight', 'bold', ...
                          'BackgroundColor', [0.15 0.15 0.15], ...
                          'ForegroundColor', 'white');
    
    % Results text box - LISTBOX for scrolling
    txtResults = uicontrol('Parent', resultPanel, ...
                           'Style', 'listbox', ...
                           'String', {
                               '╔═══════════════════════════════════════════════════════════╗';
                               '║          GLOVE DEFECT DETECTION SYSTEM                    ║';
                               '╚═══════════════════════════════════════════════════════════╝';
                               '';
                               '  Welcome to the Glove Defect Detection System';
                               '';
                               '  Please load an image to begin analysis.';
                               '';
                               '  Detectable Defects:';
                               '    • Tears (body defects)';
                               '    • Surface Contamination (foreign objects)';
                               '    • Stains (discoloration and marks)';
                               '';
                               '═══════════════════════════════════════════════════════════';
                           }, ...
                           'Position', [10 10 1110 170], ...
                           'FontSize', 10, ...
                           'FontName', 'FixedWidth', ...
                           'BackgroundColor', [0.15 0.15 0.15], ...
                           'ForegroundColor', 'white',...
                           'Max', 2, ...
                           'Min', 0);
    
    % Initialize handles structure
    handles.image = [];
    handles.gloveMask = [];
    handles.fileName = '';
    handles.axOriginal = axOriginal;
    handles.axResult = axResult;
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
        
        set(txtResults, 'String', {
            '╔═══════════════════════════════════════════════════════════╗';
            '║              IMAGE LOADED SUCCESSFULLY                    ║';
            '╚═══════════════════════════════════════════════════════════╝';
            '';
            '  Ready for defect detection analysis.';
            '';
            '  Click "Detect All Defects" to analyze all defect types';
            '  or select individual detection buttons for specific analysis.';
            '';
            '═══════════════════════════════════════════════════════════';
        });
    end
    
    function detectAllDefects(~, ~)
        handles = guidata(fig);
        
        if isempty(handles.image)
            errordlg('Please load an image first.', 'No Image');
            return;
        end
        
        set(txtResults, 'String', {
            '╔═══════════════════════════════════════════════════════════╗';
            '║              PROCESSING... PLEASE WAIT                    ║';
            '╚═══════════════════════════════════════════════════════════╝';
            '';
            '  Analyzing image for defects...';
            '';
            '  Step 1: Segmenting glove region';
            '  Step 2: Detecting contamination';
            '  Step 3: Detecting tears';
            '  Step 4: Detecting stains';
            '';
            '═══════════════════════════════════════════════════════════';
        });
        drawnow;
        
        I = handles.image;
        
        % Segment glove using HSV
        gloveMask = segment_glove_hsv(I);
        handles.gloveMask = gloveMask;
        guidata(fig, handles);
        
        % Detect all defect types
        [contamMask, contamStats, numContam] = detect_contamination(I, gloveMask);
        handles.contamMask = contamMask;
        guidata(fig, handles);
        
        [tearMask, tearStats, numTears] = detect_tears(I, gloveMask);


        [stainMask, stainStats, numStains] = detect_stains(I, gloveMask);
        handles.stainMask = stainMask;
        guidata(fig, handles);
        
        % Display results
        axes(axResult);
        imshow(I);
        hold on;
        
        % Draw tears (red)
        for i = 1:length(tearStats)
            rectangle('Position', tearStats(i).BoundingBox, ...
                      'EdgeColor', 'r', 'LineWidth', 2);
            plot(tearStats(i).Centroid(1), tearStats(i).Centroid(2), ...
                 'r+', 'MarkerSize', 12, 'LineWidth', 2);
            text(tearStats(i).BoundingBox(1), tearStats(i).BoundingBox(2)-10, ...
                 'TEAR', 'Color', 'r', 'FontSize', 9, 'FontWeight', 'bold');
        end
        
        % Draw contamination (red) 
        for i = 1:length(contamStats)
            % Draw bounding box
            rectangle('Position', contamStats(i).BoundingBox, ...
                      'EdgeColor', [1 0 0], 'LineWidth', 1);
            
            % Draw large X marker covering the contamination area
            bbox = contamStats(i).BoundingBox;
            %x1 = bbox(1);
            %y1 = bbox(2);
            %x2 = bbox(1) + bbox(3);
            %y2 = bbox(2) + bbox(4);
            
            % Draw diagonal cross (X)
            %plot([x1 x2], [y1 y2], 'Color', [1 0 0], 'LineWidth', 3);  % Red X
            %plot([x2 x1], [y1 y2], 'Color', [1 0 0], 'LineWidth', 3);  % Red X
            
            % Label
            text(bbox(1), bbox(2)-10, ...
                 'CONTAMINATION', 'Color', 'r', 'FontSize', 10, 'FontWeight', 'bold');
        end
        
        % Draw stains (yellow)
        for i = 1:length(stainStats)
            rectangle('Position', stainStats(i).BoundingBox, ...
                      'EdgeColor', [1 0.8 0], 'LineWidth', 2);
            plot(stainStats(i).Centroid(1), stainStats(i).Centroid(2), ...
                 'y+', 'MarkerSize', 12, 'LineWidth', 2);
            text(stainStats(i).BoundingBox(1), stainStats(i).BoundingBox(2)-10, ...
                 'STAIN', 'Color', [0.9 0.7 0], 'FontSize', 9, 'FontWeight', 'bold');
        end
        
        hold off;
        title(axResult, 'All Defects Detected', 'FontSize', 12, 'FontWeight', 'bold');
        
        % Update results text - PROFESSIONAL LISTBOX FORMAT
        totalDefects = numTears + numContam + numStains;
        
        % Create professional formatted output
        resultLines = {
            '╔═══════════════════════════════════════════════════════════╗';
            '║              DEFECT DETECTION SUMMARY                     ║';
            '╚═══════════════════════════════════════════════════════════╝';
            '';
            sprintf('  Total Defects Found: %d', totalDefects);
            '';
            '─────────────────────────────────────────────────────────────';
            '  DEFECT BREAKDOWN:';
            '─────────────────────────────────────────────────────────────';
            '';
            sprintf('    [TEARS]           : %d detected', numTears);
            sprintf('    [CONTAMINATION]   : %d detected', numContam);
            sprintf('    [STAINS]          : %d detected', numStains);
            '';
            '─────────────────────────────────────────────────────────────';
            sprintf('  QUALITY STATUS: %s', getQualityStatus(totalDefects));
            '─────────────────────────────────────────────────────────────';
            '';
            '  VISUAL LEGEND:';
            '    • Red Box/Marker     → Tears';
            '    • Blue Box + Red X   → Contamination';
            '    • Yellow Box/Marker  → Stains';
            '';
            '═══════════════════════════════════════════════════════════';
        };
     
        set(txtResults, 'String', resultLines);
    end
    
    function detectTearsOnly(~, ~)
        handles = guidata(fig);
        
        if isempty(handles.image)
            errordlg('Please load an image first.', 'No Image');
            return;
        end
        
        I = handles.image;
        gloveMask = segment_glove_hsv(I);
        
        handles = guidata(fig);

        %if isfield(handles, 'contamMask')
        %    contamMask = handles.contamMask;
        %elseif isfield(handles, 'stainMask')
        %    stainMask = handles.stainMask;
        %else
        %    % Fallback: compute contamination if not done yet
        %    [contamMask, ~, ~] = detect_contamination(I, gloveMask);
        %end
        
        % Detect tear
        [tearMask, tearStats, numTears] = detect_tears(I, gloveMask);
                
        displaySingleDefect(I, tearStats, 'TEAR', 'r', 'Tears Detected');
        
        % Professional results display
        resultLines = {
            '╔═══════════════════════════════════════════════════════════╗';
            '║                  TEAR DETECTION RESULTS                   ║';
            '╚═══════════════════════════════════════════════════════════╝';
            ...
            sprintf('  Total Tears Detected: %d', numTears);
            ...
            '  Detection Area: Glove body (excluding contamination)';
            '  Detection Method: Topology-based void detection';
            '';
            '═══════════════════════════════════════════════════════════';
        };
        
        set(txtResults, 'String', resultLines);
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
        
        % Professional results display
        resultLines = {
            '╔═══════════════════════════════════════════════════════════╗';
            '║                 STAIN DETECTION RESULTS                   ║';
            '╚═══════════════════════════════════════════════════════════╝';
            '';
            sprintf('  Total Stains Detected: %d', numStains);
            '';
            '  Detection Type: Surface discoloration & marks';
            '  Detection Method: Statistical deviation analysis';
            '';
            '═══════════════════════════════════════════════════════════';
        };
        
        set(txtResults, 'String', resultLines);
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
        handles.contamMask = contamMask;
    
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
    
        % Professional results display
        resultLines = {
            '╔═══════════════════════════════════════════════════════════╗';
            '║            CONTAMINATION DETECTION RESULTS                ║';
            '╚═══════════════════════════════════════════════════════════╝';
            '';
            sprintf('  Total Contamination Detected: %d', numContam);
            '';
            '  Detection Type: Foreign objects on glove surface';
            '  Examples: Rubber bands, strings, dirt, residue';
            '';
            '═══════════════════════════════════════════════════════════';
        };
        
        set(txtResults, 'String', resultLines);
    end

    
    function displaySingleDefect(I, stats, label, color, titleStr)
        handles = guidata(fig);  % Use fig instead of gcf
        axes(handles.axResult);
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
        title(handles.axResult, titleStr, 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'white');
    end
    
    function clearDisplay(~, ~)
        axes(axOriginal);
        cla;
        title(axOriginal, 'Original Image', ...
              'FontSize', 12, ...
              'FontWeight', 'bold', ...
              'Color', 'white');

        axis off;
        
        axes(axResult);
        cla;
        title(axResult, 'Detection Result', ...
              'FontSize', 12, ...
              'FontWeight', 'bold', ...
              'Color', 'white');
        axis off;
        
        set(txtResults, 'String', {
            '╔═══════════════════════════════════════════════════════════╗';
            '║          GLOVE DEFECT DETECTION SYSTEM                    ║';
            '╚═══════════════════════════════════════════════════════════╝';
            '';
            '  Display cleared. Ready for next analysis.';
            '';
            '  Please load an image to begin detection.';
            '';
            '═══════════════════════════════════════════════════════════';
        });
        
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