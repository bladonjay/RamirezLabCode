function RunOptoRunningWheel(settings)
% $Id: RunTreadmill.m 4831 2013-05-13 19:56:09Z nrobinson
% commented by JH Bladon
% RunTreadmill runs a treadmill task with a gui, will open a treadmill
% object, a joystick object (if possible) and will try to connect to the
% plexon map server.

if ~isempty(timerfindall)
    fprintf('You already have this task running, close old program \n');
    return
end


%% start with some default settings
session.comment = '';       % no default comments yet
session.date = now();       % all annotations

session.box1.laserpulses=[];
session.box1.events=[];
session.box1.ratname='mouse 1';

session.box2.laserpulses=[];
session.box2.events=[];
session.box2.ratname='mouse 2';

sessionnum=0;

runthreshold=5;

defsettings.box1.Activate=false;
defsettings.box1.PinA='D2';
defsettings.box1.PinB='D3';
defsettings.box1.wheelpins={'D18','D19'};
defsettings.box1.LaserPin='D22';
defsettings.box1.PokeTime=.5; % seconds
defsettings.box1.CoolDown=1; % seconds
defsettings.box1.lasermode='Front poke';

defsettings.box2.Activate=false;
defsettings.box2.PinA='D4';
defsettings.box2.PinB='D5';
defsettings.box2.wheelpins={'D20','D21'};
defsettings.box2.LaserPin='D11';
defsettings.box2.PokeTime=.5; % seconds
defsettings.box2.CoolDown=1; % seconds
defsettings.box1.lasermode='Front poke';

boxnames={'box1','box2'};

if(nargin == 0)
    settings = checksettings();
else
    settings = checksettings(settings);
end

%% start all our hard parameters
% set random seed so we dont get the same randomizer every time
rstream = RandStream('mt19937ar','Seed', mod(prod(clock()),2^32));
% set the global time stream
RandStream.setGlobalStream(rstream);

% just in case we work with plexon
% plex server number
plexserver = 0;

% Initiate poke sensor

a=arduino('COM4','Mega2560','Libraries',{'Adafruit/MotorShieldV2', 'I2C', 'SPI', 'Servo','rotaryEncoder'});
% turn the ir beams on  (indicator light on arduino)
% writeDigitalPin(a,'D13',1);
wheel(1)=rotaryEncoder(a,settings.box1.wheelpins{1},settings.box1.wheelpins{2},100);
wheel(2)=rotaryEncoder(a,settings.box2.wheelpins{1},settings.box2.wheelpins{2},100);

% make sure you clear the arduino on cleanup
autocloselaserserial = onCleanup(@() clear('a'));


% set up our time recorder, that will use a 0.01 second update rate
tim = timer('StartFcn',@startfcn,'TimerFcn',@timerfcn,...
    'StopFcn',@stopfcn,'ErrorFcn',@errorfcn,'Period',0.2,...
    'ExecutionMode','fixedDelay','Name','Main RunTreadmill Timer');



% do you need to save on shutdown?
% this goes true once the animal has done something (e.g. has poked)
needtosave = false;

% start a history seed
history = [];

% create a time reference point
timeref = tic;

%% session annotations
Pokenum=0; % start at 0 pokes


%% open the gui
h = TaskGUI();
set(h.controls,'CloseRequestFcn',@closeButton)
set(h.timer,'CloseRequestFcn',@toggleTimer);
%set(h.open,'Callback',@openHist); % gotta kill this thing
set(h.save,'Callback',@saveHist);
set(h.pause,'Callback',@playpause);
set(h.reset,'Callback',@resetchecker);
set(h.showtimer,'Callback',@toggleTimer);

set(h.TestLaser1,'Callback',@TestLaser1);
set(h.TestLaser2,'Callback',@TestLaser2);

set(h.Activate1,'Callback',@Activate1);
set(h.Activate2,'Callback',@Activate2);

set(h.settings,'Callback',@settingscallback);


applysettings;


%% timer functions

% start stops screensaver and switches the start stop button
    function startfcn(varargin)
        output(h.maindsp, 'Disabling Screen Saver...');
        [status, result] = dos('FlipSS /off');
        if(status == 0), output(h.maindsp, 'Screen Saver Disabled.');
        else, output(h.maindsp, regexprep(result,'\n',' '));
        end
        
        
        set(h.pause,'String','Pause');
        set(h.pause,'Enable','on');
        
        if ~any([settings.box1.Activate settings.box2.Activate])
            output(h.maindsp,'No boxes enabled, stopping');
            stop(tim);
        end
        for i=1:2
            if settings.(boxnames{i}).Activate
                set(h.(['TestLaser' num2str(i)]),'Enable','off');
            end
        end
        
        
    end

    function errorfcn(varargin)
        output(h.maindsp, 'Error encountered.');
    end

% stop function adds screen saver, and switches stop button
    function stopfcn(varargin)
        output(h.maindsp, sprintf('Pausing...'));
        output(h.maindsp, 'Enabling Screen Saver...');
        [status, result] = dos('FlipSS /on');
        if(status == 0); output(h.maindsp, 'Screen Saver Enabled.');
        else output(h.maindsp, regexprep(result,'\n',' '));
        end
        set(h.pause,'String','Start');
        set(h.pause,'Enable','on');
        set(h.TestLaser1,'Enable','on');
        set(h.TestLaser2,'Enable','on');
    end



% timer function will execute every 0.01 seconds once you press the
% start button on the GUI
    function timerfcn(varargin)
        % here we process each input
        % should probably have two fx, one to get events, one to
        % process events
                
        getEvents;
        
        process_event;
        
        % if were using plexon, see if plexons sending an event
        
        % and update timestamps
        updateTimers();
        updateCounter();
        updateDisplay();

    end


%% this is the process evetn fx, e.g. the output response fx

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%% EVENT FUNCTIONS %%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



    function getEvents
        % this gathers the inputs
        % will record an input history here, e.g. ongoing record of poking,
        % will probably ts each tick and record broken or not.
        % these are organized by left first then right, and each cell is a
        % box
        
        % e.g. session.wheel{1}(1,:)= left box 1 beam status and ts of
        % checker
        
        %*************************
        % events looks like: front pin, back pin, turncount, instaspeed, 0 timestamp
        %***********************
        
        % for each box, if its active, add to the session, and needtosave
        for i=1:2
            if settings.(boxnames{i}).Activate
                % tack on to the matrix
                session.(boxnames{i}).events=[session.(boxnames{i}).events;...
                    % read front port 1 is broken
                    ~readDigitalPin(a,settings.(boxnames{i}).PinA) ...
                    % read back port 1 is broken
                    ~readDigitalPin(a,settings.(boxnames{i}).PinB) ...
                    % tick count,        instant speed,       laser    timestamp
                    
                    readCount(a,wheel(i)) readSpeed(a,wheel(i))  0 toc(timeref)];
                
                needtosave=1;
            end
        end
        
    end

% this processes the outputs, only responds given the event history
    function process_event
        % if either cell has anything in it, and its running, see what we
        % should do
        % for each box
        for i=1:2
            % get the stats
            tmpsession=session.(boxnames{i});
            tmpsettings=settings.(boxnames{i});
            eventstat=tmpsession.events;
            lasermode=settings.(boxnames{i}).lasermode;
            % LASERMODES = {'Front poke','Back poke','Rolly','None'};
            
            % % if we're running, 1
            if size(eventstat,1)>2 && settings.(boxnames{i}).Activate
                if ~strcmpi(lasermode,'none')
                    % distil crucial stat into 1's and 0's
                    if strcmpi(lasermode,'front poke')
                        trigger=eventstat(:,[1 6]);
                    elseif strcmpi(lasermode,'back poke')
                        trigger=eventstat(:,[2 6]);
                    elseif strcmpi(lasermode,'rolly')
                        trigger=eventstat(:,[4 6]);
                        trigger(:,1)=abs(trigger(:,1))>=runthreshold;
                    end
                    
                    
                    % if he's responding
                    if trigger(end,1)>0
                        % and he just started the response
                        if trigger(end-1,1)<0
                            % add to number of pokes
                            output(h.maindsp, sprintf('Rat in box %d initiated %.2f',i,toc));
                        end
                        
                        % if this response ts is greater than cooldown time
                        if  trigger(end)>tmpsession.laserpulses(end)+tmpsettings.CoolDown
                            % find all the samples in the past second (the delay)
                            startidx = trigger(:,2)>trigger(end)-tmpsettings.PokeTime;
                            recentbreaks=trigger(startidx,1);
                            % now if those all are positive... hit him
                            if ~any(recentbreaks==0)
                                % add a laser pulse to the log
                                session.(boxnames{i}).laserpulses = [session.(boxnames{i}).laserpulses; toc(timeref)];
                                session.(boxnames{i}).events(5,end)=1;
                                % pulse it
                                writeDigitalPin(a,tmpsettings.LaserPin,0);
                                writeDigitalPin(a,tmpsettings.LaserPin,1);
                                % and write to ledger
                                output(h.maindsp, sprintf('pulsing laser in box %d, ts (%.2f)', i, toc(timeref)));
                                
                            end
                        end
                    else % if hes not
                        % and he just stopped
                        if trigger(end-1,2)>runthreshold
                            % then tell the terminal
                            output(h.maindsp, sprintf('Rat in box %d stopped %.2f',i,toc));
                        end
                    end
                end
            end
        end
    end


%% laser functions, this is defunct, but we could resurrect it
    function armlaser(event_num, event_time)
        lap_ = mod(Pokenum-1,numel(objectlist))+1;
        if(~isempty(laserlist) && Pokenum > 0 && laserlist(lap_)==2 &&...
                settings.laserduration > 0)
            pulselaser(laserserial,0,settings.laserduration);
            output(h.maindsp, 'Pulsing Laser (arm)');
        end
    end




%% for modifying settings (opens new window)
    function settingscallback(varargin) %#ok<VANUS>
        settings = changesettings(settings, h);
        settings = checksettings(settings);
        applysettings;
    end

    function applysettings() % apply arduino settings
        clear a wheel
        a=arduino('COM4','Mega2560','Libraries',{'Adafruit/MotorShieldV2', 'I2C', 'SPI', 'Servo','rotaryEncoder'});
        wheel(1)=rotaryEncoder(a,settings.box1.wheelpins{1},settings.box1.wheelpins{2},100);
        wheel(2)=rotaryEncoder(a,settings.box2.wheelpins{1},settings.box2.wheelpins{2},100);
        % apply the settings, specifically all the pins
        configurePin(a,settings.box1.PinA,'Pullup');
        configurePin(a,settings.box1.PinB,'Pullup');
        configurePin(a,settings.box2.PinA,'Pullup');
        configurePin(a,settings.box2.PinB,'Pullup');
        
        updateDisplay();
        updateCounter();
    end

    function settings = checksettings(settings)
        if(nargin==0); settings = defsettings;
        else
            % Now check all the rest of the settings, making sure they are
            % at least present and the correct variable type.
            settings = checkfieldtypes(settings, defsettings);
        end
        
        
    end

% check fieldtypes makes sure that new struct doesnt have missing
% or messed up fields (it only turns bad fields into old struct
% fields, othewise it takes the new structs fields
    function newstruct = checkfieldtypes(newstruct, refstruct)
        fields = fieldnames(refstruct);
        
        for j = 1:size(fields,1)
            % if new struct doesnt have the field, or its class is
            % wrong, new struct takes old structs field
            if(~isfield(newstruct,fields{j}) || ...
                    ~isa(newstruct.(fields{j}),class(refstruct.(fields{j}))))
                newstruct.(fields{j}) = refstruct.(fields{j});
                
                % if newstruct has a field but its empty, or it has a nan,
                % use old struct var
            elseif(isnumeric(newstruct.(fields{j})) && ...
                    (isempty(newstruct.(fields{j})) || ...
                    any(isnan(newstruct.(fields{j})))))
                newstruct.(fields{j}) = refstruct.(fields{j});
                warning(['Invalid number entered for ' fields{j} ', resetting to default value.'],'Invalid Entry');
            
                % otherwise, keep new struct variable
            elseif(isstruct(newstruct.(fields{j})))
                newstruct.(fields{j}) = checkfieldtypes(newstruct.(fields{j}), refstruct.(fields{j}));
            end
        end
    end
%% saving and history functions
% gotta kill this


    function success = saveHist(varargin) %#ok<VANUS>
        
        if(needtosave)
            % add to comments
            session.comment = char(inputdlg({'Session Comments'},...
                'Session Comments',10,{session.comment}));
            
            % add mouse names
            dlgtitle='Name your mice';
            prompt={'Name Box 1 Mouse','Name Box 2 Mouse'};
            defaultans={session.box1.ratname,session.box2.ratname};
            
            % if yo named your micede
            answer = inputdlg(prompt,dlgtitle,[1 30],defaultans);
            stockans={'oscar','tickle me elmo'};
            if length(answer)>1
            for i=1:2
                if ~isempty(answer{i})
                    session.(['box' num2str(i)]).ratname=answer{i};
                else
                    output(h.maindsp,'You didnt name your animal, he''ll get a funny name');
                    session.(['box' num2str(i)]).ratname=stockans{i};
                end
            end
            elseif length(answer)<1
                for i=1:2, session.(['box' num2str(i)]).ratname=stockans(i); end
            else
                session.box2.ratname=stockans(2);
            end
            
            session.settings = settings;
            % get save directory
            savedir=uigetdir(matlabroot,'Choose folder to save your session');
            if isempty(savedir), savedir=matlabroot; end
            % get save name, if you rename it something that exists, touhg
            % noggies
            savename=inputdlg('Name your session','Session Name',[1 30],{['Session-' char(datetime('now'))]});
            if isempty(savename{1}), savename={['Session-' char(datetime('now'))]}; end
            
            
            try
                save([savedir '\' savename{1}],'session');
                output(h.maindsp, sprintf('History for %s and %s saved.',...
                    session.box1.ratname,session.box2.ratname));
                needtosave = false;
                
                % try to save as an xls doc.. too much of a pain in the
                % ass...
                 xldata={session.box1.ratname,session.box1.lasermode,'','','',session.box2.ratname,session.box2.lasermode,'','','';...
                     'left port','right port','Distance','intsaspeed', 'zaps','left port','right port','Distance','intsaspeed', 'zaps'};
                 
                 animaldata{1}=session.box1.events;
                 animaldata{2}=session.box2.events;
                 
                 % if either is empty, fill it with nans
                 if isempty(animaldata{1}), animaldata{1}=nan(size(animaldata{2})); end
                 if isempty(animaldata{2}), animaldata{2}=nan(size(animaldata{1})); end   
                 
                 % if theyre uneven, fill end of one with nans
                 if diff(cellfun(@(a) size(a,1),animaldata))~=0
                     % whose a bigger mat, take the other
                     [longest, idx]=max([size(animaldata{2},1) size(animaldata{1},1)]);
                     animaldata{idx}(end:longest,1:4)=nan;
                 end
                 
                 % combine, and make an excel 
                 xldata=[xldata;num2cell(animaldata{1}), num2cell(animaldata{2})];

                xlswrite([savedir '\' savename{1} '-exceldata'],xldata);
                success=true;
                
            catch
                success=false;
                output(h.maindsp,'Saving didnt work');
                needtosave=true;
            end
        else, msgbox('Nothing to save.'); success=true;
        end
        updateDisplay();
    end
%% display functions
    function updateDisplay()
        % for each box
        for i=1:2
            settingsstr = sprintf('');

            % if its active write something
            if settings.(['box' num2str(i)]).Activate
                ratname=session.(boxnames{i}).ratname;
                runstats=session.(boxnames{i}).events;
                settingsstr = ['Active, Lasermode=' settings.(boxnames{i}).lasermode ];
                % if this box is active, what has he done
                if size(runstats,1)>=2
                    % get number of pokes
                    summarystats(1) = sum(diff(runstats(:,1))==1);
                    summarystats(2) = sum(diff(runstats(:,2))==1);
                    % now get dist travelled
                    summarystats(3)=sum(diff(abs(runstats(:,3))));
                    summarystats(4)=sum(abs(runstats(:,4))>runthreshold)*5;
                    
                else, summarystats=[0 0 0 0 0];
                end
                
                zaps=size(session.(boxnames{i}).laserpulses,1);                
                % add these variables to the settings string
                settingsstr=[{[settingsstr ...
                    'Mouse ' ratname]};{[...
                    'left pokes ' num2str(summarystats(1))...
                     ' right pokes ' num2str(summarystats(2))]};{[...
                    'ran ' num2str(summarystats(3)) ' ticks &' num2str(summarystats(4)) 'secs']};{[...   
                   'stims=' num2str(zaps)]}];
                if(needtosave)
                    set(h.save,'Enable','on');
                else
                    set(h.save,'Enable','off');
                end
            else
                settingsstr=[settingsstr 'Inactive'];
            end
            set(h.(['settings' num2str(i) 'dsp']),'String',settingsstr);
        end
    end

% this is for the maind isplay
    function output(display, str)
        output_list = get(display,'String');
        output_list = output_list(end:-1:1);
        num = length(output_list)+1;
        str = strtrim(str);
        output_list{end+1} = sprintf('%3d  %s',num,str);
        set(display,'String',output_list(end:-1:1));
        drawnow
    end
%%
    % this is just the current time in minutes and seconds from start of
    % session
    function updateTimers()
        ts = toc(timeref);
        if(ishandle(h.timerstr))
            timestr = sprintf('%2.0f:%02.0f',floor(ts/60),mod(floor(ts),60));
            set(h.timerstr,'String',timestr);
        end
    end

    % this is the counter of licks, zaps for each rat
    function updateCounter()
        if(ishandle(h.counter))
            % Automatically loop back to the beginning of the list once
            % you reach the end.
            summary={}; zaps=[];
                %output(h.maindsp,'updating counter');

            for i=1:2
                %output(h.maindsp,'updating counter2');

                if settings.(['box' num2str(i)]).Activate
                    % grab pokes
                    eventstat=session.(boxnames{i}).events;
                   
                    if size(runstats,1)>=2
                    % get number of pokes
                    summary{i}(1) = sum(diff(runstats(:,1))==1);
                    summary{i}(2) = sum(diff(runstats(:,2))==1);
                    % now get dist travelled
                    summary{i}(3)=sum(diff(abs(runstats(:,3))));
                    summary{i}(4)=sum(abs(runstats(:,4))>runthreshold)*5;
                    
                    else, summary{i}=[0 0 0 0 0];
                    end
                    zaps(i)=size(session.(boxnames{i}).laserpulses(:,1));
                    % add these variables to the settings string
                   
                    if(needtosave)
                        set(h.save,'Enable','on');
                    else
                        set(h.save,'Enable','off');
                    end
                else
                    summary{i}=[0 0 0 0 0];
                    zaps(i) = 0;
                end    
            end
            counterstats=['1 poked ' num2str(summary{1}([1 2])) ', ran ' num2str(summary{1}(3)) ' ticks, '  num2str(summary{1}(4)) ' secs (' num2str(zaps(1)) ') \n'...
                '2 poked ' num2str(summary{2}([1 2])) ', ran ' num2str(summary{2}(3)) ' ticks, '  num2str(summary{2}(4)) ' secs (' num2str(zaps(2)) ')'];
            % Display lap number, object
            set(h.counter,'String',sprintf(counterstats));
        end
    end
%% reset the error checker
    function success = resetchecker(varargin)
        if(islogical(varargin{1}) && varargin{1})
            button = 'Yes';
        else
            button = questdlg('Are you sure you want to reset?','Reset Confirmation...','Yes','No','Yes');
        end
        
        if(strcmp(button,'Yes') && promptSaveSession)
            success = reset();
        else
            output(h.maindsp, 'Save failed or reset cancelled');
            success = false;
        end
    end

    function success = reset()
        needtosave = false;
        
        timeref = tic;
        
        Pokenum = 1;
        sessionnum = 0;
        session.comment = '';
        session.date = now();
        
        
        session.box1.laserpulses=[];
        session.box1.events=[];
        session.box1.ratname='mouse 1';

        session.box2.laserpulses=[];
        session.box2.events=[];
        session.box2.ratname='mouse 2';
        
        
        % If arduino is working, good else, fix it
        try
            writeDigitalPin(a,'D13',1);
            writeDigitalPin(a,'D13',0);
        catch
            applysettings();
        end
        
        set(h.maindsp,'String',{'  1  Session Reset.'});
        
        if(ishandle(h.counter))
            set(h.timerstr,'String','0');
            set(h.counter,'String','0');
            set(h.timerstr,'ForegroundColor','white');
            set(h.counter,'ForegroundColor','white');
        end
        
        updateDisplay();
        updateCounter();
        success = true;
    end
%%
    function success = promptSaveSession()
        if(needtosave)
            button = questdlg('Save unsaved session?','Saving Session...');
            switch button
                case {'Yes'}
                    success = saveHist();
                case {'No'}
                    button2 = questdlg('Are you sure? You will lose your unsaved session.','Clear Session Confirmation...','Yes','No','No');
                    switch button2
                        case {'Yes'}
                            success = true;
                        otherwise
                            success = false;
                    end
                otherwise
                    success = false;
            end
        else
            success = true;
        end
    end
%% top button actions
% if we're pausing, run stop button
    function playpause(varargin) %#ok<VANUS>
        % If currently running, then stop.
        if(strcmp(tim.Running,'on'))
            % actually i think this button switch is redundent
            set(h.pause,'Enable','off');
            stop(tim);
            % If stopped, then start running.
        else
            set(h.pause,'Enable','off');
            start(tim);
        end
    end

    function closeButton(source, varargin) %#ok<VANUS>
        if(strcmp(tim.Running,'off') && promptSaveSession)
            
            delete(source);
            if(ishandle(h.timer))
                delete(h.timer);
            end
            if(isvalid(tim))
                delete(tim);
            end
            clear a wheel;
            if any(instrfindall)
                fprintf(2,'Manually closing Arduino. \n');
                delete(instrfindall);
            end
        else warndlg('You must click ''Pause'' before closing this window.','Cannot Close');
        end
    end

    function toggleTimer(varargin) %#ok<VANUS>
        switch get(h.timer,'Visible')
            case 'on'
                set(h.timer,'Visible','off');
                set(h.showtimer,'String','Show Timer');
            case 'off'
                set(h.timer,'Visible','on');
                set(h.showtimer,'String','Hide Timer');
                %maximize(h.timer);
        end
    end

%% activate and test button functions

    function Activate1(varargin)
        % if box is active, deactivate and give option to activate again
        if settings.box1.Activate
            set(h.Activate1,'String','Activate 1');
            settings.box1.Activate=false;
        else % if box is inactivated, activate, and set to de
            set(h.Activate1,'String','Dectivate 1');
            settings.box1.Activate=true;
        end
        updateDisplay();
    end

    function Activate2(varargin)
        if settings.box2.Activate
            set(h.Activate2,'String','Activate 2');
            settings.box2.Activate=false;
        else
            set(h.Activate2,'String','Dectivate 2');
            settings.box2.Activate=true;
        end
        updateDisplay();
    end


    function TestLaser1(varargin)
        output(h.maindsp,sprintf('Testing Laser in Box 1'));
        writeDigitalPin(a,settings.box1.LaserPin,0);
        writeDigitalPin(a,settings.box1.LaserPin,1);
        session.box1.laserpulses=[session.box1.laserpulses; toc(timeref)];
    end

    function TestLaser2(varargin)
        output(h.maindsp,sprintf('Testing Laser in Box 2'));
        writeDigitalPin(a,settings.box2.LaserPin,0);
        writeDigitalPin(a,settings.box2.LaserPin,1);
        session.box2.laserpulses=[session.box2.laserpulses; toc(timeref)];
    end
        
%% Organize the windows for the gui thats made at top
    function h = TaskGUI()
        screen = get(0,'ScreenSize');
        winsize = [450 600];
        
        h.controls = figure('Name','Opto-Reward Task',...
            'NumberTitle','off','MenuBar','none',...
            'Position', [10 (screen(4)-winsize(2)-30) winsize]);
        
        h.buttons = uipanel('Parent',h.controls,...
            'Units','normalized','Position',[0.01 0.92 0.98 0.07]);
        
        h.buttons1 = uipanel('Parent',h.controls,...
            'Units','normalized','Position',[0.01 0.76 0.48 0.15]);
        
        h.buttons2 = uipanel('Parent',h.controls,...
            'Units','normalized','Position',[0.51 0.76 0.48 0.15]);
        
        % top six
%         h.open = uicontrol(h.controls,'Style','pushbutton',...
%             'Units','normalized','Position',[0.02 0.93 0.15 0.05],...
%             'String','Open');

        h.save = uicontrol(h.controls,'Style','pushbutton',...
            'Units','normalized','Position',[0.18 0.93 0.15 0.05],...
            'String','Save','Enable','off');
        
        h.pause = uicontrol(h.controls,'Style','pushbutton',...
            'Units','normalized','Position',[0.34 0.93 0.15 0.05],...
            'String','Start');
        
        h.reset = uicontrol(h.controls,'Style','pushbutton',...
            'Units','normalized','Position',[0.50 0.93 0.15 0.05],...
            'String','Reset');
        
        h.settings = uicontrol(h.controls,'Style','pushbutton',...
            'Units','normalized','Position',[0.66 0.93 0.15 0.05],...
            'String','Settings');
        
        h.showtimer = uicontrol(h.controls,'Style','pushbutton',...
            'Units','normalized','Position',[0.82 0.93 0.15 0.05],...
            'String','Timer');
        
        % Box 1 Specific buttons
        h.TestLaser1 = uicontrol(h.controls,'Style','pushbutton',...
            'Units','normalized','Position',[0.02 0.85 0.20 0.05],...
            'String','Test Laser 1');
        
        h.Activate1 = uicontrol(h.controls,'Style','pushbutton',...
            'Units','normalized','Position',[0.24 0.85 0.20 0.05],...
            'String','Activate Box 1');
        
        h.settings1dsp = uicontrol(h.controls,'Style','text',...
            'Units','normalized','Position',[0.02 0.77 0.46 0.06],...
            'BackGroundColor',[1 1 1]);
        
        
        % Box 2 Specific buttons
        h.TestLaser2 = uicontrol(h.controls,'Style','pushbutton',...
            'Units','normalized','Position',[0.56 0.85 0.20 0.05],...
            'String','Test Laser 2');
        
        h.Activate2 = uicontrol(h.controls,'Style','pushbutton',...
            'Units','normalized','Position',[0.77 0.85 0.20 0.05],...
            'String','Activate Box 2');
        
        
        h.settings2dsp = uicontrol(h.controls,'Style','text',...
            'Units','normalized','Position',[0.52 0.77 0.46 0.06],...
            'BackGroundColor',[ 1 1 1]);
        
        
        %% general lower panels
        
        
        h.maindsp = uicontrol(h.controls,'Style','edit',...
            'Units','normalized','Position',[0.01 0.01 0.98 0.74],...
            'BackgroundColor','white','HorizontalAlignment','left',...
            'Max',2,'Enable','inactive');
        
        h.timer = figure('Name','Lap Counter',...
            'NumberTitle','off','MenuBar','none','Visible','off',...
            'Position', [5 39 screen(3)-11 screen(4)-63]);
        
        h.counter = uicontrol(h.timer,'Style','text',...
            'Units','normalized','Position',[0 0.5 1 .5],...
            'BackgroundColor','black','ForegroundColor','white',...
            'FontUnits','normalized','FontSize',.45);
        
        h.timerstr = uicontrol(h.timer,'Style','text',...
            'Units','normalized','Position',[0 0 1 .5],...
            'BackgroundColor','black','ForegroundColor','white',...
            'FontUnits','normalized','FontSize',.95);
    end

%% change settings window
    function settings = changesettings(settings, h)
        LASERMODES = {'Front poke','Back poke','Rolly','None'};
        box1mode = 1; box2mode=1;
        for j = 1:length(LASERMODES)
            if(strcmpi(settings.box1.lasermode,LASERMODES{j})); box1mode = j; end
            if(strcmpi(settings.box2.lasermode,LASERMODES{j})); box2mode = j; end
        end
        
        parentwin = get(h.controls,'Position');
        
        setwin = dialog('Name','Settings',...
            'NumberTitle','off','MenuBar','none');
        
        
        % need left pins, right pins, left poke times, right poke times
        
        % box 1
        % laser pins
        labels.PinB1 = uicontrol(setwin,'Style','text',...
            'String','Box 1 Pin "B" ');
        controls.PinB1 = uicontrol(setwin,'Style','edit',...
            'BackgroundColor','white','String',settings.box1.PinB);
        
        labels.PinA1 = uicontrol(setwin,'Style','text',...
            'String','Box 1 Pin "A"');
        controls.PinA1 = uicontrol(setwin,'Style','edit',...
            'BackgroundColor','white','String',settings.box1.PinA);
        
        labels.wheelpins1 = uicontrol(setwin,'Style','text',...
            'String','Box 1 Wheel Pins ');
        controls.wheelpins1 = uicontrol(setwin,'Style','edit','Max',2,...
            'BackgroundColor','white','String',settings.box1.wheelpins);
        
        labels.lasermode1 = uicontrol(setwin,'Style','text',...
                'String','Laser Mode:');
        controls.lasermode1 = uicontrol(setwin,'Style','popupmenu',...
                'String',LASERMODES,'Value',box1mode);
            
        labels.LaserPin1 = uicontrol(setwin,'Style','text',...
            'String','Box 1 Laser Pin');
        controls.LaserPin1 = uicontrol(setwin,'Style','edit',...
            'BackgroundColor','white','String',settings.box1.LaserPin);
        
        labels.PokeTime1 = uicontrol(setwin,'Style','text',...
            'String','Box 1 Poke Duration (s)');
        controls.PokeTime1 = uicontrol(setwin,'Style','edit',...
            'BackgroundColor','white','String',settings.box1.PokeTime);
        
        labels.CoolDown1 = uicontrol(setwin,'Style','text',...
            'String','Box 1 Cool Down (s)');
        controls.CoolDown1 = uicontrol(setwin,'Style','edit',...
            'BackgroundColor','white','String',settings.box1.CoolDown);
        
        % box 2 laser pins
        labels.PinB2 = uicontrol(setwin,'Style','text',...
            'String','Box 2 Pin "B" ');
        controls.PinB2 = uicontrol(setwin,'Style','edit',...
            'BackgroundColor','white','String',settings.box2.PinB);
        
        labels.PinA2 = uicontrol(setwin,'Style','text',...
            'String','Box 2 Pin "A" ');
        controls.PinA2 = uicontrol(setwin,'Style','edit',...
            'BackgroundColor','white','String',settings.box2.PinA);
        
        labels.wheelpins2 = uicontrol(setwin,'Style','text',...
            'String','Box 2 Wheel Pins ');
        controls.wheelpins2 = uicontrol(setwin,'Style','edit','Max',2,...
            'BackgroundColor','white','String',settings.box2.wheelpins);
                
        labels.lasermode2 = uicontrol(setwin,'Style','text',...
                'String','Laser Mode:');
        controls.lasermode2 = uicontrol(setwin,'Style','popupmenu',...
                'String',LASERMODES,'Value',box2mode);
            
        labels.LaserPin2 = uicontrol(setwin,'Style','text',...
            'String','Box 2 Laser Pin');
        controls.LaserPin2 = uicontrol(setwin,'Style','edit',...
            'BackgroundColor','white','String',settings.box2.LaserPin);
        
        labels.PokeTime2 = uicontrol(setwin,'Style','text',...
            'String','Box 2 Poke Duration (s)');
        controls.PokeTime2 = uicontrol(setwin,'Style','edit',...
            'BackgroundColor','white','String',settings.box2.PokeTime);
        
        labels.CoolDown2 = uicontrol(setwin,'Style','text',...
            'String','Box 2 Cool Down (s)');
        controls.CoolDown2 = uicontrol(setwin,'Style','edit',...
            'BackgroundColor','white','String',settings.box2.CoolDown);
        
        
        settingnames = fieldnames(controls);
        numrows = length(settingnames);
        winsize = [200 30+25*numrows];
        set(setwin,'Position',[parentwin(1)+50,...
            parentwin(2)+parentwin(4)-winsize(2)-150,winsize]);
        
        for j = 1:numrows
            ypos = winsize(2)-j*25;
            set(labels.(settingnames{j}),'Position',[05 ypos 90 16]);
            set(controls.(settingnames{j}),'Position',[100 ypos 95 20]);
        end
        
        uicontrol(setwin,'Style','pushbutton','String','OK',...
            'Position',[110 05 30 20],'Callback',{@(x,y) uiresume(setwin)});
        uicontrol(setwin,'Style','pushbutton','String','Cancel',...
            'Position',[145 05 50 20],'Callback',{@(x,y) delete(setwin)});
        
        % wait to set the window
        uiwait(setwin);
        
        % change everything once windows done
        if(ishandle(setwin))
            settings.box1.PinB= get(controls.PinB1,'String'); 
            settings.box1.PinA = get(controls.PinA1,'String');
            settings.box1.wheelpins=get(controls.wheelpins1,'String');
            settings.box1.lasermode = LASERMODES{get(controls.lasermode1,'Value')};
            settings.box1.LaserPin = get(controls.LaserPin1,'String');
            settings.box1.PokeTime = str2double(get(controls.PokeTime1,'String'));
            settings.box1.CoolDown = str2double(get(controls.CoolDown1,'String'));

            settings.box2.PinB= get(controls.PinB2,'String'); 
            settings.box2.PinA = get(controls.PinA2,'String');
            settings.box2.wheelpins=get(controls.wheelpins2,'String');
            settings.box2.lasermode = LASERMODES{get(controls.lasermode2,'Value')};
            settings.box2.LaserPin = get(controls.LaserPin2,'String');
            settings.box2.PokeTime = str2double(get(controls.PokeTime2,'String'));
            settings.box2.CoolDown = str2double(get(controls.CoolDown2,'String'));
         
            delete(setwin);
        end
    end

        function showerror(err)
            warning(err.message);
            for j = 1:size(err.stack,1)
                fprintf(2,'Error in ==> %s at %d\n',...
                    err.stack(j).name,err.stack(j).line);
            end
        end
end