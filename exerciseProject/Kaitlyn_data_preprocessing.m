% Kaitlyn Data PreProcessing
%
% import the datas

% choose a directory
[mydir]=uigetdir;

% find the files in that directory
%pullfiles=dir(mydir);
goodfiles=getAllFiles(mydir);
%goodfiles=[3:length(pullfiles)];

clear allsession;
for k=1:length(goodfiles)
    tempsession=load(goodfiles{k});
    tempsession.name=goodfiles{k};
    allsession(k)=tempsession;

end



%% aggregate into a single spreadsheet
dash=WhichDash;

clear recordings
%session=AllSession;
cumnum=1;
for i=1:length(allsession)
    
    

    temp=allsession(i).session.box1;
    temp.comment=allsession(i).session.comment;
    temp.filename=allsession(i).name(find(allsession(i).name==dash,1,'last')+1:end-4);
    temp.date=datestr(allsession(i).session.date);
    recordings(cumnum)=temp;
    %recordings(cumnum).date=session(i).session.date;
    
    cumnum=cumnum+1;
    

    temp=allsession(i).session.box2;
    temp.comment=allsession(i).session.comment;
    temp.filename=allsession(i).name(find(allsession(i).name==dash,1,'last')+1:end-4);
    temp.date=datestr(allsession(i).session.date);
    recordings(cumnum)=temp;
    cumnum=cumnum+1;
end

%% now aggregate data for each animal.  If that animal doesnt have data, keep his data at zero
allnames={};
for i=1:length(recordings)
    allnames{i}=recordings(i).filename;
end

for i=1:length(recordings)
    % if we recorded events for this guy
    if ~isempty(recordings(i).events)
        % this is the sum of ticks that the animal moved over the whole
        % session.  A tick is a really small distance so we'll have to
        % convert
        recordings(i).totaldist=sum(abs(diff(recordings(i).events(:,3))));
        % scrub really long intervals, and put a zero before it. This makes
        % sure that we take the time interval over which the speed was
        % fast, not the time interval after
        dt=diff(recordings(i).events(:,end)); dt(dt>2)=nan; dt=[dt; 0; 0];
        runinds=abs([0; recordings(i).events(:,4)]);
        % the old way
        % recordings(i).totaltimeran=sum(abs(recordings(i).events(:,4))>10)/dt;
        
        % this is the sum of the intervals during which he was running
        recordings(i).totaltimeran=nansum(dt(runinds>10))/60;
        recordings(i).maxspeed=max(recordings(i).events(:,4)); % the fastest time hes recorded
        
        okdatapoints=recordings(i).events(:,4)>10;
        recordings(i).averagespeed=mean(abs(recordings(i).events(okdatapoints,4)));
        
        recordings(i).sessionduration=(recordings(i).events(end)-recordings(i).events(1,4))/60;
        recordings(i).isrunner=1;
        recordings(i).stims=length(recordings(i).laserpulses);
    else % these are for the ones where the box was turned off
        % dont do this, we need this animals data, its just going to come
        % from his/her yoked counterpart
        myname=recordings(i).filename;
        mypartner=cellfun(@(a) any(strfind(a,myname)),allnames);
        mypartner(i)=false;
        partnerindex=find(mypartner);
        recordings(i).events=recordings(mypartner).events;
        recordings(i).laserpulses=recordings(mypartner).laserpulses;
        fprintf('no data for session %d \n',i);
        recordings(i).totaldist=nan;
        recordings(i).totaltimeran=nan;
        recordings(i).maxspeed=nan;
        recordings(i).averagespeed=nan;
        recordings(i).sessionduration=nan;
        recordings(i).isrunner=0;
        recordings(i).stims=length(recordings(i).laserpulses);
    end
end


%%
% kill all the noname animals and the lower 'm's
% kill all the no mouses
remove=[];
for i=1:length(recordings)
    if strfind(recordings(i).ratname,'tickle me elmo')
        remove(i)=1;
    else
        remove(i)=0;
    end
    if recordings(i).ratname(1)=='m'
        recordings(i).ratname(1)='M';
    end
    
    % which sessions are opto sessions
    if contains(recordings(i).filename,'opto')
        recordings(i).optosession=1;
    else
        recordings(i).optosession=0;
    end
    
    % which sessions are recall sessions
    if contains(recordings(i).filename,'runtp') ||...
            contains(recordings(i).filename,'recall')
        recordings(i).recallsession=1;
    else
        recordings(i).recallsession=0;
    end
    
    % maybe it would be good to number the days because the running
    % protocol is always the same ther are always six days
    
end
recordings(logical(remove))=[];
%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%% THIS BUILDS THE VARIABLE WITH ALL THE DATA
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%
% HERE YOU NEED TO DO SOME LINE EDITS:
% hard code here

cohort=zeros(1,length(recordings));
cohort(1:88)=1;
cohort([89:172, 199, 200 241 242])=2;
cohort([173:198, 201:232, 243:272])=3;
cohort(cohort==0)=4;

for i=1:length(cohort)
    recordings(i).cohort=cohort(i);
end
% now fix up your empty matrix data, any yoked guy with data, or run
% session without data needs to be fixed here.
recordings(151).ratname = 'M5';
recordings(152).ratname = 'M6';
recordings(153).ratname = 'M1';
recordings(154).ratname = 'M2';
recordings(159).ratname = 'M4';
recordings(160).ratname = 'M3';
recordings(286).ratname = 'M14';
% so we'll combine every session by mouse and each mouse will have a
% cohort, a partner, and a condition
% first import all our freezing data
% and freezdata looks like this
% top two rows are the ts of the session
% leftmost col is mouse number
% cells in matrix are freezing percentages
% rightmost col is the freezing threshold for each animal... a bit sketchy

%%
% and put together the whole thing
mouse=1;
for i=1:max([recordings.cohort])
    % for each cohort first gather the cohort
    mycohort=recordings([recordings.cohort]==i);
    % set up each animal
    [allmice,~,mouseinds]=unique({mycohort.ratname});
    % cat all session
    if exist('thisfreezedata','var')
    thisfreezdata=freezdata([freezdata.cohort]==i);
    end
    for j=1:length(allmice)
        RunnyData(mouse).name=allmice{j};
        RunnyData(mouse).cohort=i;
        RunnyData(mouse).rundata=mycohort(mouseinds==j);
        % now find the freezydata
        RunnyData(mouse).isyoked=any([RunnyData(mouse).rundata.isrunner]==0);
        mousenum=str2num(allmice{j}(2:end));
        if exist('thisfreezedata','var')
    
        for k=1:length(thisfreezdata)
            freezind=cell2mat(thisfreezdata(k).data(:,1));
            if any(freezind==mousenum)
            RunnyData(mouse).freezdata(k).data=[cell2mat(thisfreezdata(k).data([1 2],:));...
                cell2mat(thisfreezdata(k).data(freezind==mousenum,:))];
            RunnyData(mouse).freezdata(k).name=thisfreezdata(k).name;
            else
                
            end
        end
        end
    % now get at the freezing data
    mouse=mouse+1;
    end
end
% we can organize each animals recording schedule by which day it occurred
% and hten we can save the labels to decipher which was training and which
% was stim/yoked after the fact
% Kaitlyin will have an excel sheet that has information about their
% freezyness and their stims etc. and we can use that to plot running by
% freezy by stim by yoked

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%% END ORGANIZATIONAL STUFF NOW ANALYSIS %%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% this is hard coded, dont worry about
% add a mouse number into the struct so i can find the guys easier
for i=1:length(RunnyData)
    myname=RunnyData(i).name;
    mynum=str2num(myname(2:end));
    RunnyData(i).mousenum=mynum;
end



% animals to exclude: e.g. turn into control animals
% bla1 m7,  m8,  m9,  m11, m12,
% bla3 m1, m2, m3,
% bla4 m1, m5 m9 m10 m13 m14


% bla2 is a control cohort
% bilat animals:

% bla3 m6  m7 m9 m11 m13 m14 bilateral expression
% bla4 m6 m11 bilateral


% indices for the animals:

badexpression=[7 8 9 11 12 31 32 33 46 50 54 55 58 59];
isbilateral=[36 37 39 41 43 44 51 56];

for i=1:length(RunnyData)
    if any(i==badexpression) || RunnyData(i).cohort==2
        RunnyData(i).iscontrol=true;
    else
        RunnyData(i).iscontrol=false;
    end
    if any(i==isbilateral)
        RunnyData(i).isbilateral=true;
    else
        RunnyData(i).isbilateral=false;
    end
end
RunnyData(23).rundata(7) = [];
RunnyData(27).rundata(7) = [];



% BLA4:
% bla4 doesnt have a recall session 
% m1 bad
% m5 questionable (super outlier, and bad labeling)
% m6 was paired with m5 so they both may be wierd

% m15 is bad
% m12 died after opto run and will have no freeze recall

% so each animal to exclude is turned into a control
% all animals in cohort 2 are controls


%%
% guys with missing data
% bla1 m2 no test or recall- he died
% bla2 m13 no test or shock - he died too
% bla2 m15 died
% bla2 m7 died


% if there are doubles ditch the file that is named wierd

% plot each cohort alone, do a mean and median plot for running distnace
% speed and time for each day (sorted)
% split out for runners and yoked
% and do a timeline for the recall for each animal to see if theres a trend

% now organize by date
for i=1:length(RunnyData)
    [~,index] = sortrows(datenum({RunnyData(i).rundata.date}.')); 
    RunnyData(i).rundata = RunnyData(i).rundata(index); 
    clear index;
end


%%

% one option is to find th first nudge per animal and use that as start

% for recall day some animals are put in ten minutes late
% these animals were put in ten minutes later:
% ask alec to see if he can
% bla1 m3 14 minutes late
% bla1 m5 15 minutes late
% bla1 m7 15 minutes late
% bla1 m9 15 minutes late
% bla1 m11 15 minutes late
% bla1 m15 15 minutes late
% bla1 m13 15 minutes late

% bla2 late mice are: m2, m4, m6, m9, m11, m14 all 10 minutes late

% bla3 late mice are:
% m2, m4, m6, m8, m10, m12, m14 all exactly 10 minutes late

% okay, gotta recalc all these damn numbers

% okay so i'll just reset the counters for these animals
startreset=[ 1 3 14;
            1 5 15;
            1 7 15;
            1 9 15;
            1 11 15;
            1 13 15;
            1 15 15;
            2 2 10;
            2 4 10;
            2 6 10;
            2 9 10;
            2 11 10;
            2 14 10;
            3 2 10;
            3 4 10;
            3 6 10;
            3 8 10;
            3 10 10;
            3 12 10;
            3 14 10];
for i=1:length(RunnyData)
    for j=1:size(startreset,1)
        if RunnyData(i).cohort==startreset(j,1) && RunnyData(i).mousenum==startreset(j,2) 
            RunnyData(i).rundata(end).sessionduration=RunnyData(i).rundata(end).sessionduration-startreset(j,3);
        end
    end
end

%%
% load kaitlynRunnyData4-1-19

load('L:\Dropbox (Eichenbaumers)\Eichenbaumers Team Folder\CogNeuro\Projects\Bladon Squad\Opto\Ramirez opto\Kaitlyn\KaitlynData5-21-19.mat');
load('L:\Dropbox (Eichenbaumers)\Eichenbaumers Team Folder\CogNeuro\Projects\Bladon Squad\Opto\Ramirez opto\Kaitlyn\KaitlynFreezData5-21-19.mat');


%% now slot the freezing data into each animal

for i=1:length(RunnyData)
    % match cohort
    cohortf=FreezingData(RunnyData(i).cohort).data;
    cohortf([2:end],15)=cohortf(3,15);
    % now try to match mouse
    mousematch=find(cell2mat(cohortf(3:end,1))==RunnyData(i).mousenum);
    if ~isempty(mousematch)
        % now make a new mat from that
        RunnyData(i).FreezData=cohortf([1 2 mousematch+2],:);
    end
end


% now renatem BlaStim
BlaStim=RunnyData;