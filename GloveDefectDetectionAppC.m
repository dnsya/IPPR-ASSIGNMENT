classdef GloveDefectDetectionAppC < matlab.apps.AppBase
    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                matlab.ui.Figure
        
        % Main Image Display
        ImagePanel                 matlab.ui.container.Panel
        ImageAxes                  matlab.ui.control.UIAxes
        
        % Image Gallery
        GalleryPanel                matlab.ui.container.Panel
        GalleryGrid                 matlab.ui.container.GridLayout
        GalleryScrollPanel          matlab.ui.container.Panel
        
        % Defect Selection
        DefectPanel                 matlab.ui.container.Panel
        DefectType1CheckBox         matlab.ui.control.CheckBox
        DefectType2CheckBox         matlab.ui.control.CheckBox
        DefectType3CheckBox         matlab.ui.control.CheckBox
        
        % Control Buttons
        ControlPanel                matlab.ui.container.Panel
        ImportButton                matlab.ui.control.Button
        AnalyzeButton               matlab.ui.control.Button
        ClearButton                 matlab.ui.control.Button
        PreviousButton              matlab.ui.control.Button
        NextButton                  matlab.ui.control.Button
        ResetButton                 matlab.ui.control.Button
        ImageCounterLabel           matlab.ui.control.Label
        
        % Console
        ConsolePanel                matlab.ui.container.Panel
        ConsoleTextArea             matlab.ui.control.TextArea
    end
    
    % Private properties
    properties (Access = private)
        ImageFiles = {}              % Cell array of image file paths
        CurrentImageIndex = 0        % Index of currently displayed image
        CurrentImage = []            % Currently loaded image
        DefectOverlay = []           % Overlay with defect markers
        GalleryButtons = {}          % Gallery thumbnail buttons (Panels)
    end

    % Component initialization
    methods (Access = private)
        % Create UIFigure and components
        function createComponents(app)

            % 1. Create UIFigure (Hidden during setup)
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1320 860];
            app.UIFigure.Name = 'Glove Defect Detection System';
            app.UIFigure.Color = [0.94 0.94 0.94];
            app.UIFigure.AutoResizeChildren = 'off';
            app.UIFigure.Scrollable = 'off';
            app.UIFigure.WindowState = 'normal';
            
            % --- PANEL DEFINITIONS ---
            % Image Panel
            app.ImagePanel = uipanel(app.UIFigure);
            app.ImagePanel.Title = 'Image Display & Detection Results';
            app.ImagePanel.FontWeight = 'bold';
            app.ImagePanel.Position = [10 220 450 570];
            
            app.ImageAxes = uiaxes(app.ImagePanel);
            app.ImageAxes.Position = [10 10 430 530];
            app.ImageAxes.XTick = []; 
            app.ImageAxes.YTick = [];
            app.ImageAxes.Box = 'on'; 
            app.ImageAxes.DataAspectRatio = [1 1 1]; 
            
            % Gallery Panel
            app.GalleryPanel = uipanel(app.UIFigure);
            app.GalleryPanel.Title = 'Image Gallery';
            app.GalleryPanel.FontWeight = 'bold';
            app.GalleryPanel.Position = [470 470 720 320];
            app.GalleryPanel.Scrollable = 'on';
            app.GalleryPanel.AutoResizeChildren = 'off';
            
            app.GalleryScrollPanel = uipanel(app.GalleryPanel);
            app.GalleryScrollPanel.Position = [10 10 700 280];
            app.GalleryScrollPanel.Scrollable = 'on';
            app.GalleryScrollPanel.AutoResizeChildren = 'off';
            app.GalleryScrollPanel.BorderType = 'none';
            
            % Defect Panel
            app.DefectPanel = uipanel(app.UIFigure);
            app.DefectPanel.Title = 'Defect Selection';
            app.DefectPanel.FontWeight = 'bold';
            app.DefectPanel.Position = [470 220 240 240];
            
            app.DefectType1CheckBox = uicheckbox(app.DefectPanel);
            app.DefectType1CheckBox.Text = 'Sticky/Fused Fingers';
            app.DefectType1CheckBox.Position = [20 170 150 22];
            app.DefectType1CheckBox.Value = 1; % Default checked

            app.DefectType2CheckBox = uicheckbox(app.DefectPanel);
            app.DefectType2CheckBox.Text = 'Burn Marks';
            app.DefectType2CheckBox.Position = [20 130 150 22];
            app.DefectType2CheckBox.Value = 1; % Default checked

            app.DefectType3CheckBox = uicheckbox(app.DefectPanel);
            app.DefectType3CheckBox.Text = 'Holes';
            app.DefectType3CheckBox.Position = [20 90 150 22];
            app.DefectType3CheckBox.Value = 1; % Default checked

            
            % Control Panel
            app.ControlPanel = uipanel(app.UIFigure);
            app.ControlPanel.Title = 'Controls';
            app.ControlPanel.FontWeight = 'bold';
            app.ControlPanel.Position = [720 220 470 240];
            
            app.ImportButton = uibutton(app.ControlPanel, 'push');
            app.ImportButton.Text = 'Import Images';
            app.ImportButton.Position = [15 150 150 45];
            app.ImportButton.FontWeight = 'bold';
            app.ImportButton.BackgroundColor = [0 0.4667 0.6588];
            app.ImportButton.FontColor = [1 1 1];
            app.ImportButton.ButtonPushedFcn = @(btn, event) ImportButtonPushed(app);
            
            app.AnalyzeButton = uibutton(app.ControlPanel, 'push');
            app.AnalyzeButton.Text = 'Analyze';
            app.AnalyzeButton.Position = [180 150 130 45];
            app.AnalyzeButton.FontWeight = 'bold';
            app.AnalyzeButton.BackgroundColor = [0.1569 0.6549 0.2706];
            app.AnalyzeButton.FontColor = [1 1 1];
            app.AnalyzeButton.ButtonPushedFcn = @(btn, event) AnalyzeButtonPushed(app);
            
            app.ClearButton = uibutton(app.ControlPanel, 'push');
            app.ClearButton.Text = 'Clear';
            app.ClearButton.Position = [325 150 130 45];
            app.ClearButton.FontWeight = 'bold';
            app.ClearButton.BackgroundColor = [0.8627 0.2078 0.2706];
            app.ClearButton.FontColor = [1 1 1];
            app.ClearButton.ButtonPushedFcn = @(btn, event) ClearButtonPushed(app);
            
            app.PreviousButton = uibutton(app.ControlPanel, 'push');
            app.PreviousButton.Text = '← Previous';
            app.PreviousButton.Position = [15 90 150 45];
            app.PreviousButton.BackgroundColor = [1 0.7608 0.0275];
            app.PreviousButton.ButtonPushedFcn = @(btn, event) PreviousButtonPushed(app);
            
            app.NextButton = uibutton(app.ControlPanel, 'push');
            app.NextButton.Text = 'Next →';
            app.NextButton.Position = [180 90 130 45];
            app.NextButton.BackgroundColor = [1 0.7608 0.0275];
            app.NextButton.ButtonPushedFcn = @(btn, event) NextButtonPushed(app);
            
            app.ResetButton = uibutton(app.ControlPanel, 'push');
            app.ResetButton.Text = 'Reset';
            app.ResetButton.Position = [325 90 130 45];
            app.ResetButton.BackgroundColor = [0.4235 0.4627 0.5137];
            app.ResetButton.FontColor = [1 1 1];
            app.ResetButton.ButtonPushedFcn = @(btn, event) ResetButtonPushed(app);
            
            app.ImageCounterLabel = uilabel(app.ControlPanel);
            app.ImageCounterLabel.Text = 'No images loaded';
            app.ImageCounterLabel.Position = [15 50 200 22];
            
            % Console Panel
            app.ConsolePanel = uipanel(app.UIFigure);
            app.ConsolePanel.Title = 'Console Output';
            app.ConsolePanel.FontWeight = 'bold';
            app.ConsolePanel.Position = [10 10 1180 200];
            app.ConsolePanel.BackgroundColor = [0.1176 0.1176 0.1176];
            app.ConsolePanel.ForegroundColor = [0 1 0];
            
            app.ConsoleTextArea = uitextarea(app.ConsolePanel);
            app.ConsoleTextArea.Position = [10 10 1160 165];
            app.ConsoleTextArea.BackgroundColor = [0.1176 0.1176 0.1176];
            app.ConsoleTextArea.FontColor = [0 1 0];
            app.ConsoleTextArea.FontName = 'Courier New';
            app.ConsoleTextArea.Editable = 'off';
            app.ConsoleTextArea.Value = {'> System initialized. Ready...'};
            
            % Show and center
            app.UIFigure.Visible = 'on';
            drawnow;
            movegui(app.UIFigure, 'center');
        end
    end

    % App creation and deletion
    methods (Access = public)
        function app = GloveDefectDetectionAppC
            createComponents(app)
        end
        function delete(app)
            delete(app.UIFigure)
        end
    end
    
    % Callback functions
    methods (Access = private)
        
        function ImportButtonPushed(app)
            [files, path] = uigetfile({'*.jpg;*.png;*.bmp', 'Image Files'}, ...
                'Select Images', 'MultiSelect', 'on');
            if isequal(files, 0), return; end
            if ~iscell(files), files = {files}; end
            
            app.ImageFiles = fullfile(path, files);
            app.CurrentImageIndex = 1;
            createGallery(app);
            displayImage(app, 1);
            updateImageCounter(app);
        end
        
        % Helper function to add console message with auto-scroll
        function addConsoleMessage(app, message)
            app.ConsoleTextArea.Value = [app.ConsoleTextArea.Value; message];
            % Auto-scroll to bottom
            drawnow;
            scroll(app.ConsoleTextArea, 'bottom');
        end
        
        function AnalyzeButtonPushed(app)
            if isempty(app.CurrentImage)
                addConsoleMessage(app, '> ERROR: No image loaded.');
                return;
            end
            
            % Check which defects are selected
            detectSticky = app.DefectType1CheckBox.Value;
            detectBurns = app.DefectType2CheckBox.Value;
            detectHoles = app.DefectType3CheckBox.Value;
            
            if ~detectSticky && ~detectBurns && ~detectHoles
                addConsoleMessage(app, '> Select a defect type first.');
                return;
            end
            
            addConsoleMessage(app, '> Starting analysis...');
            
            detectDefects(app, detectSticky, detectBurns, detectHoles);
        end

        function ClearButtonPushed(app)
            if app.CurrentImageIndex > 0
                displayImage(app, app.CurrentImageIndex);
                addConsoleMessage(app, '> Detection cleared.');
            end
        end

        function PreviousButtonPushed(app)
            if app.CurrentImageIndex > 1
                app.CurrentImageIndex = app.CurrentImageIndex - 1;
                displayImage(app, app.CurrentImageIndex);
                updateImageCounter(app);
            end
        end

        function NextButtonPushed(app)
            if app.CurrentImageIndex < length(app.ImageFiles)
                app.CurrentImageIndex = app.CurrentImageIndex + 1;
                displayImage(app, app.CurrentImageIndex);
                updateImageCounter(app);
            end
        end

        function ResetButtonPushed(app)
            app.ImageFiles = {};
            app.CurrentImageIndex = 0;
            app.CurrentImage = [];
            cla(app.ImageAxes);
            app.ImageCounterLabel.Text = 'No images loaded';
            app.ConsoleTextArea.Value = {'> System reset.'};
            
            % Clear Gallery
            app.GalleryButtons = {};
            if isvalid(app.GalleryScrollPanel)
                delete(app.GalleryScrollPanel.Children);
            end
        end

        function displayImage(app, index)
            if index < 1 || index > length(app.ImageFiles), return; end
            try
                app.CurrentImage = imread(app.ImageFiles{index});
                cla(app.ImageAxes);
                imshow(app.CurrentImage, 'Parent', app.ImageAxes);
                axis(app.ImageAxes, 'image'); 
                
                [~, name, ext] = fileparts(app.ImageFiles{index});
                addConsoleMessage(app, sprintf('> Displaying: %s%s', name, ext));
                
                updateGalleryHighlight(app);
            catch ME
                addConsoleMessage(app, sprintf('> ERROR: %s', ME.message));
            end
        end

        % function updateGalleryHighlight(app)
        %     for i = 1:length(app.GalleryButtons)
        %         panel = app.GalleryButtons{i};
        %         if isvalid(panel)
        %             if i == app.CurrentImageIndex
        %                 panel.BorderType = 'line';
        %                 panel.HighlightColor = [0 0.47 0.8];
        %             else
        %                 panel.BackgroundColor = app.GalleryPanel.BackgroundColor; 
        %                 panel.BorderType = 'none';
        %             end
        %         end
        %     end
        % end

        function updateGalleryHighlight(app)
            for i = 1:length(app.GalleryButtons)
                panel = app.GalleryButtons{i};
                if isvalid(panel)
                    if i == app.CurrentImageIndex
                        panel.BorderType = 'line';
                        panel.HighlightColor = [0 0.47 0.8];
                        scroll(app.GalleryPanel, panel);
                        
                    else
                        panel.BackgroundColor = app.GalleryPanel.BackgroundColor; 
                        panel.BorderType = 'none';
                    end
                end
            end
        end

        function updateImageCounter(app)
            if isempty(app.ImageFiles)
                app.ImageCounterLabel.Text = 'No images loaded';
            else
                app.ImageCounterLabel.Text = sprintf('Image %d of %d', app.CurrentImageIndex, length(app.ImageFiles));
            end
        end

        % INTEGRATED DEFECT DETECTION ORCHESTRATOR
        function detectDefects(app, detectSticky, detectBurns, detectHoles)
            img = app.CurrentImage;
            
            % Store all detected boxes
            allBoxes = {};
            allLabels = {};
            allColors = {};
            
            totalDefects = 0;
            
            %% 1. STICKY/FUSED FINGERS DETECTION
            if detectSticky
                addConsoleMessage(app, '> Detecting sticky/fused fingers...');
                
                % CALL EXTERNAL FUNCTION
                [fusedBoxes, numFused] = detect_StickyFingers(img);
                
                if numFused > 0
                    for i = 1:size(fusedBoxes, 1)
                        allBoxes{end+1} = fusedBoxes(i, :);
                        allLabels{end+1} = 'FUSED';
                        allColors{end+1} = 'c';
                    end
                    totalDefects = totalDefects + numFused;
                    addConsoleMessage(app, sprintf('> Found %d fused finger region(s)', numFused));
                else
                    addConsoleMessage(app, '> No fused fingers detected');
                end
            end
            
            %% 2. BURN MARKS AND HOLES DETECTION
            if detectBurns || detectHoles
                addConsoleMessage(app, '> Detecting burn marks and holes...');
                
                % CALL EXTERNAL FUNCTION
                [burnBoxes, holeBoxes, numBurns, numHoles] = detect_BurnsAndHoles(img, detectBurns, detectHoles);
                
                if detectBurns && numBurns > 0
                    for i = 1:size(burnBoxes, 1)
                        allBoxes{end+1} = burnBoxes(i, :);
                        allLabels{end+1} = 'BURN';
                        allColors{end+1} = 'r';
                    end
                    totalDefects = totalDefects + numBurns;
                    addConsoleMessage(app, sprintf('> Found %d burn mark(s)', numBurns));
                elseif detectBurns
                    addConsoleMessage(app, '> No burn marks detected');
                end
                
                if detectHoles && numHoles > 0
                    for i = 1:size(holeBoxes, 1)
                        allBoxes{end+1} = holeBoxes(i, :);
                        allLabels{end+1} = 'HOLE';
                        allColors{end+1} = 'b';
                    end
                    totalDefects = totalDefects + numHoles;
                    addConsoleMessage(app, sprintf('> Found %d hole(s)', numHoles));
                elseif detectHoles
                    addConsoleMessage(app, '> No holes detected');
                end
            end
            
            %% 3. DISPLAY RESULTS ON GUI
            cla(app.ImageAxes);
            imshow(img, 'Parent', app.ImageAxes);
            axis(app.ImageAxes, 'image'); 
            hold(app.ImageAxes, 'on');
            
            % Draw all detected defects
            for i = 1:length(allBoxes)
                bb = allBoxes{i};
                color = allColors{i};
                label = allLabels{i};
                
                % Expand bounding box slightly for visibility
                expand = 10;
                bb_expanded = [bb(1)-expand, bb(2)-expand, bb(3)+2*expand, bb(4)+2*expand];
                
                % Draw rectangle
                rectangle(app.ImageAxes, 'Position', bb_expanded, ...
                    'EdgeColor', color, 'LineWidth', 3);
                
                % Add label
                text(app.ImageAxes, bb(1), bb(2)-15, label, ...
                    'Color', color, 'FontWeight', 'bold', 'FontSize', 12, ...
                    'BackgroundColor', 'w');
            end
            
            hold(app.ImageAxes, 'off');
            
            % Final summary
            if totalDefects > 0
                addConsoleMessage(app, sprintf('> ANALYSIS COMPLETE: %d total defect(s) - REJECT', totalDefects));
            else
                addConsoleMessage(app, '> ANALYSIS COMPLETE: No defects - PASS');
            end
        end

        function createGallery(app)
            % Clear existing gallery items
            if isvalid(app.GalleryScrollPanel)
                delete(app.GalleryScrollPanel.Children);
            end
            app.GalleryButtons = {};
            
            thumbnailsPerRow = 5;
            totalItemHeight = 120; 
            spacing = 15;
            totalRows = ceil(length(app.ImageFiles) / thumbnailsPerRow);
            requiredHeight = max(280, totalRows * (totalItemHeight + spacing) + 50);
            
            % Refresh the Scroll Panel height
            app.GalleryScrollPanel.Position(4) = requiredHeight;
            
            for i = 1:length(app.ImageFiles)
                row = floor((i-1) / thumbnailsPerRow);
                col = mod(i-1, thumbnailsPerRow);
                xPos = col * (120 + spacing) + spacing;
                yPos = requiredHeight - (row + 1) * (totalItemHeight + spacing);
                
                % Thumbnail Panel
                itemPanel = uipanel(app.GalleryScrollPanel, 'Position', [xPos yPos 120 110]);
                itemPanel.BorderType = 'none';
                itemPanel.ButtonDownFcn = @(~,~) galleryButtonCallback(app, i);
                
                % Thumbnail Axes
                ax = uiaxes(itemPanel, 'Position', [5 25 110 80]);
                ax.XTick = []; ax.YTick = []; 
                ax.Toolbar.Visible = 'off';
                ax.Interactions = [];
                ax.XColor = 'none'; ax.YColor = 'none';
                
                % Display Thumbnail
                imgObj = imshow(imread(app.ImageFiles{i}), 'Parent', ax);
                axis(ax, 'image'); 
                
                % Ensure clicking the image triggers selection
                imgObj.ButtonDownFcn = @(~,~) galleryButtonCallback(app, i);
                
                % Filename Label
                [~, n, e] = fileparts(app.ImageFiles{i});
                lbl = uilabel(itemPanel, 'Text', [n e], 'Position', [5 0 110 20], 'HorizontalAlignment', 'center', 'FontSize', 8);
                lbl.Interruptible = 'off';
                
                app.GalleryButtons{i} = itemPanel;
            end
        end

        function galleryButtonCallback(app, index)
            app.CurrentImageIndex = index;
            displayImage(app, index);
            updateImageCounter(app);
        end
    end
end