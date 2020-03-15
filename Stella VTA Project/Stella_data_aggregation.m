%%
% get your directory
[mydir]=uigetdir;

% get the filenames
pullfiles=getAllFiles(mydir);

% first two are root, the rest are good files... may need to designate the
% filetypes here by asking whether the files are .mat files

for k=1:length(pullfiles)
    myfile=load(pullfiles{k});
    session(k)=myfile.session;
end

%% Good ways to plot pokes etc.
% this plots a single session
figure;



mysession=session(6);
pokes1=mysession.box1.events(:,1);
pokes2=mysession.box1.events(:,2);
pokes3=abs(mysession.box1.events(:,4))>10;
zaps=mysession.box1.events(:,5);
zaps(zaps==0)=nan;

plot(cumsum(pokes1));
hold on;
plot(cumsum(pokes2));
plot(cumsum(pokes3));
plot(zaps-5,'k*');
legend('front pokes','back pokes','rolly','zaps')
title(mysession.box1.ratname);
xlim([0 length(pokes1)]);

%%
% more plots for a single session
subplot(4,2,8);
pokes1=session.box2.events(:,1);
pokes2=session.box2.events(:,2);
pokes3=abs(session.box2.events(:,4))>10;
zaps=session.box2.events(:,5);
zaps(zaps==0)=nan;

plot(cumsum(pokes1));
hold on;
plot(cumsum(pokes2));
plot(cumsum(pokes3));
plot(zaps-5,'k*');
%legend('front pokes','back pokes','rolly','zaps')
title(session.box2.ratname);
xlim([0 length(pokes1)]);

%% numbers we need
% this aggregates all animals across all sessions
% you'll want to add more fields to this struct

cumnum=1;
for i=1:length(session)
    %session(i).session.box1.laserpulses=[];
    session(i).box1.filename=session(i).comment;
    recordings(cumnum)=session(i).box1;
    
    cumnum=cumnum+1;
    session(i).box2.filename=session(i).comment;
    recordings(cumnum)=session(i).box2;
    cumnum=cumnum+1;
end


%% This aggregates some averages for each session like...

% total counts for each port (number of pokes, or cumulitive seconds per port
% total errors: how many pokes are there with no stim?

% overall rolly counts, poke initates, withdraws and stims


for i=1:length(recordings)
    
    
    %recordings(i).totalzaps=length(recordings(i).laserpulses);
    recordings(i).totalzaps=sum(recordings(i).events(:,5));
    % start pokes
    recordings(i).frontpokes=sum(diff(recordings(i).events(:,1))==1);
    recordings(i).frontwithdraws=sum(diff(recordings(i).events(:,1))==-1);
    
    % back pokes
    recordings(i).backpokes=sum(diff(recordings(i).events(:,2))==1);
    recordings(i).backwithdraws=sum(diff(recordings(i).events(:,2))==-1);

    % rollyseconds
    recordings(i).rollyseconds=sum(recordings(i).events(:,4)>15);
    recordings(i).rollydistance=sum(abs(diff(recordings(i).events(:,3))))/400;
    
    recordings(i).sessionduration=(recordings(i).events(end,6)-recordings(i).events(2,6))/60;
    
end


%%
% now to plot all these out
% you can plot this out on your onw
% helpful functions:
% struct2cell
% cell2mat
% cellfun



    
