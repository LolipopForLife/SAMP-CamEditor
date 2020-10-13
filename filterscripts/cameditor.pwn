#include <a_samp>

#define MAX_PROJECT_NAME        45
#define MAX_PROJECT_CREATED     10

// Players Move Speed
#define MOVE_SPEED              100.0
#define ACCEL_RATE              0.03

// Players Mode
#define CAMERA_MODE_NONE    	0
#define CAMERA_MODE_FLY     	1

// Key state definitions
#define MOVE_FORWARD    		1
#define MOVE_BACK       		2
#define MOVE_LEFT       		3
#define MOVE_RIGHT      		4
#define MOVE_FORWARD_LEFT       5
#define MOVE_FORWARD_RIGHT      6
#define MOVE_BACK_LEFT          7
#define MOVE_BACK_RIGHT         8

enum E_CLIP_DATA {
	clipCamMode,
	clipFlyMode,
	clipFlyObj,
	clipclipLRold,
	clipclipUDold,
	clipLastMove,
	Float:clipAccmul,
    Float:clipOldPos[3]
}

enum E_PROJECT_DATA {
    projectID,
    projectName[MAX_PROJECT_NAME + 1],
    Float:projectFromPosX,
    Float:projectFromPosY,
    Float:projectFromPosZ,
    Float:projectToPosX,
    Float:projectToPosY,
    Float:projectToPosZ,
    projectRotSpeed,
    projectMovSpeed,
    projectCutMode
};

new 
    DB:g_iHandler,
    DBResult:g_iHandlerResults;

new 
    bool:plrOpenEditor[MAX_PLAYERS],
    plrMoving[MAX_PLAYERS],
    EditorData[MAX_PLAYERS][E_CLIP_DATA],
    ProjectData[MAX_PLAYERS][E_PROJECT_DATA];

public OnFilterScriptExit() {
    for (new i; i < MAX_PLAYERS; i ++) if (EditorData[MAX_PLAYERS][clipCamMode] == CAMERA_MODE_FLY) {
        ClosePlayerEditor(i);
    }

    db_close(g_iHandler);
	return 1;
}

public OnFilterScriptInit() {
    g_iHandler = db_open("cameditor.db");
    db_query(g_iHandler, "CREATE TABLE IF NOT EXISTS `projects` (name VARCHAR("#MAX_PROJECT_NAME"), creator VARCHAR("#MAX_PLAYER_NAME"))");
    db_query(g_iHandler, "CREATE TABLE IF NOT EXISTS `cameditor` (camid INTEGER PRIMARYKEY AUTOINCREENT, project VARCHAR("#MAX_PROJECT_NAME"), fromX FLOAT, fromY FLOAT, fromZ FLOAT, toX FLOAT, toY FLOAT, toZ FLOAT, movSpeed INTEGER DEFAULT '0', rotSpeed INTEGER DEFAULT '0', cutMode INTEGER DEFAULT '0', FOREIGN KEY (project) REFERENCES projects(name))");
    print("\n-------------------\nCamera Mode v0.0.1\n-------------------\n");

    return 1;
}

public OnPlayerConnect(playerid) {
    ClearCacheEditor(playerid);
    return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
    if (!strcmp(cmdtext, "/cameditor", true)) {
        if ((plrOpenEditor[playerid] = !plrOpenEditor[playerid])) {
            InitializeEditor(playerid);
        }
        else {
            ClosePlayerEditor(playerid);
        }
        return 1;
    }
    if (!strcmp(cmdtext, "/cancel", true)) {
        plrMoving[playerid] = 0;
        TogglePlayerFly(playerid, false);
        ShowEditorMenu(playerid);
    }
	return 0;
}

public OnPlayerUpdate(playerid) {
    if (EditorData[playerid][clipCamMode] == CAMERA_MODE_FLY) {
        new keys,ud,lr;
		GetPlayerKeys(playerid,keys,ud,lr);
 
		if(EditorData[playerid][clipFlyMode] && (GetTickCount() - EditorData[playerid][clipLastMove] > 100))
		{
		    MovePlayerCamera(playerid);
		}
		if(EditorData[playerid][clipUDold] != ud || EditorData[playerid][clipLRold] != lr)
		{
			if((EditorData[playerid][clipUDold] != 0 || EditorData[playerid][clipLRold] != 0) && ud == 0 && lr == 0)
			{   
				StopPlayerObject(playerid, EditorData[playerid][flyobject]);
				EditorData[playerid][clipFlyMode] = 0;
				EditorData[playerid][clipAccmul]  = 0.0;
			}
			else
			{
				EditorData[playerid][clipFlyMode] = GetMoveDirectionFromKeys(ud, lr);
				MovePlayerCamera(playerid);
			}
		}
		EditorData[playerid][clipUDold] = ud; 
        EditorData[playerid][clipLRold] = lr;
		return 0;
	}
    return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[]) {
    switch (dialogid) {
        case DIALOG_EDITOR_MENU: {
            if (!response || !listitem) return 1;

            switch (listitem) {
                case MENU_CREATE_PROJECT: ShowPlayerDialog(playerid, DIALOG_EDITOR_CREATE_PROJECT, DIALOG_STYLE_INPUT, "Camera Editor - Create Project", "{FFFFFF}Please type your project name below", "Select", "Back");
                case MENU_EDIT_PROJECT: ShowProjectList(playerid, DIALOG_EDITOR_EDIT_PROJECT);
                case MENU_CLOSE_EDITOR: ClosePlayerEditor(playerid);
            }
            return 1;
        }
        case DIALOG_EDITOR_CREATE_PROJECT: {
            if (!response || !listitem) 
                return InitializeEditor(playerid);

            if (isnull(inputtext))
                return ShowPlayerDialog(playerid, DIALOG_EDITOR_CREATE_PROJECT, DIALOG_STYLE_INPUT, "Camera Editor - Create Project", "{FF0000}ERROR: Project Name cannot be empty\n{FFFFFF}Please type your project name below", "Select", "Back");

            if (inputtext > MAX_PROJECT_NAME)
                return ShowPlayerDialog(playerid, DIALOG_EDITOR_CREATE_PROJECT, DIALOG_STYLE_INPUT, "Camera Editor - Create Project", "{FF0000}ERROR: Project Name must not exceeded "#MAX_PROJECT_NAME" characters\n{FFFFFF}Please type your project name below", "Select", "Back");

            if (IsProjectExists(inputtext))
                return ShowPlayerDialog(playerid, DIALOG_EDITOR_CREATE_PROJECT, DIALOG_STYLE_INPUT, "Camera Editor - Create Project", "{FF0000}ERROR: Project Name exists, please use another one\n{FFFFFF}Please type your project name below", "Select", "Back");

            if (IsSpecialCharacters(inputtext))
                return ShowPlayerDialog(playerid, DIALOG_EDITOR_CREATE_PROJECT, DIALOG_STYLE_INPUT, "Camera Editor - Create Project", "{FF0000}ERROR: Project Name contains special characters, please refrain from using that\n{FFFFFF}Please type your project name below", "Select", "Back");

            new 
                pos = -1;
            
            // strip extra characters
            if ((pos = strfind(inputtext, "\r")) != -1) strdel(inputtext, pos, pos + 1);
            if ((pos = strfind(inputtext, "\n")) != -1) strdel(inputtext, pos, pos + 1);

            new strOutput[45];
            format(strOutput, sizeof(strOutput), "You have created project \"%s\".", inputtext);
            SendClientMessage(playerid, -1, strOutput);

            OpenProject(playerid, inputtext);
            ShowEditorMenu(playerid);
            return 1;
        }
        case DIALOG_EDITOR_EDIT_PROJECT: {
            if (!response || !listitem) 
                return InitializeEditor(playerid);

            new
                pos = -1;

            // strip extra characters
            if ((pos = strfind(inputtext, "\r")) != -1) strdel(inputtext, pos, pos + 1);
            if ((pos = strfind(inputtext, "\n")) != -1) strdel(inputtext, pos, pos + 1);

            new strOutput[45];
            format(strOutput, sizeof(strOutput), "You have loaded project \"%s\".", inputtext);
            SendClientMessage(playerid, -1, strOutput);

            OpenProject(playerid, inputtext);
            ShowEditorMenu(playerid);
            return 1;
        } 
        case DIALOG_EDITOR_PROJECT_MENU: {
            if (!response) {
                SavePlayerProject(playerid);
                return InitializeEditor(playerid);
            }

            switch (listitem) {
                case EDIT_START_POSITION: {
                    if (EditorData[playerid][clipCamMode] != CAMERA_MODE_NONE)
                        TogglePlayerFly(playerid, true);

                    SendClientMessage(playerid, -1, "You're in edit mode, press 'LMB' to start editing point, and type \"/cancel\" to cancel edit mode.");
                    plrMoving[playerid] = 1;
                }
                case EDIT_ROT_SPEED: {
                    ShowPlayerDialog(playerid, EDIT_ROT_SPEED_VALUE, DIALOG_STYLE_INPUT, "Project Edit - Rot Values", "{FFFFFF}Please enter the number rotation below", "Select", "Back");
                }
                case EDIT_MOV_SPEED: {
                    ShowPlayerDialog(playerid, EDIT_MOV_SPEED_VALUE, DIALOG_STYLE_INPUT, "Project Edit - Rot Values", "{FFFFFF}Please enter the number rotation below", "Select", "Back");
                }
                case EDIT_PREVIEW: {
                    SetTimerEx(#OnPlayerFinishPreview, ProjectData[playerid][projectMovSpeed] + 2000, false, "i", playerid);
                    InterpolateCameraPos(playerid, ProjectData[playerid][projectFromPosX], ProjectData[playerid][projectFromPosY], ProjectData[playerid][projectFromPosZ], ProjectData[playerid][projectToPosX], ProjectData[playerid][projectToPosY], ProjectData[playerid][projectToPosZ], ProjectData[playerid][projectMovSpeed], ProjectData[playerid][projectCutMode]);
                    InterpolateCameraLookAt(playerid, ProjectData[playerid][projectFromPosX], ProjectData[playerid][projectFromPosY], ProjectData[playerid][projectFromPosZ], ProjectData[playerid][projectToPosX], ProjectData[playerid][projectToPosY], ProjectData[playerid][projectToPosZ], ProjectData[playerid][projectRotSpeed], ProjectData[playerid][projectCutMode]);
                }
                case EDIT_EXPORT_PROJECT: {
                    //
                }
                case EDIT_CLOSE_PROJECT: {
                    SavePlayerProject(playerid);
                    InitializeEditor(playerid);
                }
            }
            return 1;
        }
        case EDIT_ROT_SPEED_VALUE: {
            if (isnull(inputtext))
                return ShowPlayerDialog(playerid, EDIT_ROT_SPEED_VALUE, DIALOG_STYLE_INPUT, "Project Edit - Rot Values", "{FF0000}ERROR: {FFFFFF}Value must not empty\n{FFFFFF}Please enter the number rotation below", "Select", "Back");

            ProjectData[playerid][projectRotSpeed] = floatstr(inputtext);
            ShowEditorMenu(playerid);
        }
        case EDIT_MOV_SPEED_VALUE: {
            if (isnull(inputtext))
                return ShowPlayerDialog(playerid, EDIT_MOV_SPEED_VALUE, DIALOG_STYLE_INPUT, "Project Edit - Rot Values", "{FF0000}ERROR: {FFFFFF}Value must not empty\n{FFFFFF}Please enter the number rotation below", "Select", "Back");

            ProjectData[playerid][projectMovSpeed] = floatstr(inputtext);
            ShowEditorMenu(playerid);
        }
    }
    return 0;
}

public OnPlayerKeyStateChange(playerid, newkeys, oldkeys) {

    if (PRESSED(KEY_FIRE)) {
        switch (plrMoving[playerid]) {
            case 1: {
                new 
                    Float:plrPosX, Float:plrPosY, Float:plrPosZ;

                GetPlayerPos(playerid, plrPosX, plrPosY, plrPosZ);

                ProjectData[playerid][projectFromPosX] = plrPosX;
                ProjectData[playerid][projectFromPosY] = plrPosY;
                ProjectData[playerid][projectFromPosZ] = plrPosZ;

                SendClientMessage(playerid, -1, "You're in edit mode, press 'LMB' to finish editing point, and type \"/cancel\" to cancel edit mode.");
                plrMoving[playerid] = 2;
            }
            case 2: {
                new 
                    Float:plrPosX, Float:plrPosY, Float:plrPosZ;

                GetPlayerPos(playerid, plrPosX, plrPosY, plrPosZ);
            
                ProjectData[playerid][projectToPosX] = plrPosX;
                ProjectData[playerid][projectToPosY] = plrPosY;
                ProjectData[playerid][projectToPosZ] = plrPosZ;
                
                plrMoving[playerid] = 0;
                TogglePlayerFly(playerid, false);
                ShowEditorMenu(playerid);
            }
        }
    }
    return 1;
}
InitializeEditor(playerid) {
    ShowPlayerDialog(playerid, DIALOG_EDITOR_MENU, DIALOG_STYLE_LIST, "Camera Editor - Menu", "Create Project\nEdit Project\nClose Editor", "Select", "Close");
    return 1;
}

ShowEditorMenu(playerid) {
    ShowPlayerDialog(playerid, DIALOG_EDITOR_PROJECT_MENU, DIALOG_STYLE_LIST, "Camera Editor - Project Edit", "Edit Position\nRotation Speed\nMove Speed\nPreview\nExport Project\nClose Project", "Select", "Back");
    return 1;
}


ShowProjectList(playerid, todialogid) {
    new 
        strProjectList[128];
    
    g_iHandlerResults = db_query(g_iHandler, "SELECT * FROM projects");
    new rows = db_num_rows(g_iHandlerResults);

    for (new i = 0; i < rows; i ++) {
		db_get_field(g_iHandlerResults, 0, strProjectList, sizeof(strProjectList));
		db_next_row(g_iHandlerResults);

		strcat(buffer, strProjectList);
		strcat(buffer, "\n");
    }
    db_free_result(g_iHandlerResults);
    ShowPlayerDialog(playerid, todialogid, DIALOG_STYLE_LIST, "Camera Editor - List Project", strProjectList, "Select", "Back");
}

IsProjectExists(const projectName[]) {
	new
		strQuery[128];

	format(strQuery, sizeof(strQuery), "SELECT `name` FROM `projects` WHERE `name` = '%s'", projectName);
	g_iHandlerResults = db_query(g_iHandlerResults, strQuery);

	new rows = db_num_rows(g_iHandlerResults);
	db_free_result(g_iHandlerResults);
	return (rows > 0);
}

IsSpecialCharacters(const text[]) {
    for (new i = 0, l = strlen(len); i < l; i ++)
    {
        switch (text[i])
        {
            case '\\', '/', ':', '*', '"', '?', '<', '>', '|', '\'': return 1;
        }
    }
    return 0;
}

OpenProject(const projectName[]) {
   if (IsProjectOpened(projectName)) return 0;
 
    if (!IsProjectExists(projectName)) {
		new 
            str[64],
            Float:plrX, Float:plrY, Float:plrZ;
        
		GetPlayerName(playerid, str, sizeof(str));
        GetPlayerPos(playerid, plrX, plrY, plrZ);

		format(str, sizeof(str), "INSERT INTO projects (name, creator) VALUES('%s', '%s')", projectName, str);
		db_query(g_iHandler, str);

        format(str, sizeof(str), "INSERT INTO cameditor (fromX, fromY, fromZ, toX, toY, toZ, movSpeed, rotSpeed, cutMode) VALUES ('%f', '%f', '%f', '0.0', '0.0', '0.0', '0', '0', '0')", plrX, plrY, plrZ);
		db_query(g_iHandler, str);	
    }
    
    new 
        rows,
        strQuery[64];
    
    format(strQuery, sizeof(strQuery), "SELECT * FROM cameditor WHERE project = '%s'", projectName);
    g_iHandlerResults = db_query(g_iHandler, strQuery);
    
    if (db_num_rows(g_iHandler)) {

        db_get_field_assoc(g_iHandlerResults, "camid", strQuery);
        ProjectData[playerid][projectID] = strval(strQuery);

        db_get_field_assoc(g_iHandlerResults, "fromX", strQuery);
        ProjectData[playerid][projectFromPosX] = strval(strQuery);

        db_get_field_assoc(g_iHandlerResults, "fromY", strQuery);
        ProjectData[playerid][projectFromPosY] = strval(strQuery);

        db_get_field_assoc(g_iHandlerResults, "fromZ", strQuery);
        ProjectData[playerid][projectFromPosZ] = strval(strQuery);

        db_get_field_assoc(g_iHandlerResults, "toX", strQuery);
        ProjectData[playerid][projectToPosX] = strval(strQuery);

        db_get_field_assoc(g_iHandlerResults, "toY", strQuery);
        ProjectData[playerid][projectToPosY] = strval(strQuery);

        db_get_field_assoc(g_iHandlerResults, "toZ", strQuery);
        ProjectData[playerid][projectToPosZ] = strval(strQuery);

        db_get_field_assoc(g_iHandlerResults, "movSpeed", strQuery);
        ProjectData[playerid][projectMovSpeed] = strval(strQuery);

        db_get_field_assoc(g_iHandlerResults, "rotSpeed", strQuery);
        ProjectData[playerid][projectRotSpeed] = strval(strQuery);

        db_get_field_assoc(g_iHandlerResults, "cutMode", strQuery);
        ProjectData[playerid][projectCutMode] = strval(strQuery);

        db_free_result(g_iHandlerResults);
    }
    return strcat(ProjectData[playerid][projectName], name, MAX_PROJECT_NAME);
}

TogglePlayerFly(playerid, bool:toggleFly = false) {

    if (toggleFly) {
        new 
            Float:plrX, Float:plrY, Float:plrZ;
        
        GetPlayerPos(playerid, plrX, plrY, plrZ);

        EditorData[playerid][clipOldPos][0] = plrX;
        EditorData[playerid][clipOldPos][1] = plrY;
        EditorData[playerid][clipOldPos][2] = plrZ;

        EditorData[playerid][clipFlyObj] = CreatePlayerObject(playerid 19300, plrX, plrY, plrZ, 0.0, 0.0, 0.0);

        TogglePlayerSpectating(playerid, true);
        AttachCameraToPlayerObject(playerid, true);

        EditorData[playerid][clipCamMode] = CAMERA_MODE_FLY;
    }
    else {
        TogglePlayerSpectating(playerid, false);
        CancelEdit(playerid);

        DestroyPlayerObject(playerid, EditorData[playerid][clipFlyObj]);
        EditorData[playerid][clipCamMode] = CAMERA_MODE_NONE;

        SetPlayerPos(playerid, EditorData[playerid][clipOldPos][0], EditorData[playerid][clipOldPos][1], EditorData[playerid][clipOldPos][2]);
    }
    return 1;
}

ClearCacheEditor(playerid) {
    new 
        clipReset[E_CLIP_DATA];
    
    if (IsValidPlayerObject(playerid, EditorData[playerid][clipFlyObj]))
        DestroyPlayerObject(playerid, EditorData[playerid][clipFlyObj]);

    EditorData[playerid] = clipReset;
    EditorData[playerid] = CAMERA_MODE_NONE;
    return 1;
}

GetMoveDirectionFromKeys(ud, lr)
{
	new direction = 0;
    if(lr < 0)
	{
		if(ud < 0) 		direction = MOVE_FORWARD_LEFT; 	
		else if(ud > 0) direction = MOVE_BACK_LEFT; 	
		else            direction = MOVE_LEFT;          
	}
	else if(lr > 0) 
	{
		if(ud < 0)      direction = MOVE_FORWARD_RIGHT;  
		else if(ud > 0) direction = MOVE_BACK_RIGHT;    
		else			direction = MOVE_RIGHT;         
	}
	else if(ud < 0) 	direction = MOVE_FORWARD; 	
	else if(ud > 0) 	direction = MOVE_BACK;
	return direction;
}
 
MoveCamera(playerid)
{
	new Float:FV[3], Float:CP[3];
	GetPlayerCameraPos(playerid, CP[0], CP[1], CP[2]);
    GetPlayerCameraFrontVector(playerid, FV[0], FV[1], FV[2]);  
	if(noclipdata[playerid][accelmul] <= 1) noclipdata[playerid][accelmul] += ACCEL_RATE;
	new Float:speed = MOVE_SPEED * noclipdata[playerid][accelmul];
	new Float:X, Float:Y, Float:Z;
	GetNextCameraPosition(noclipdata[playerid][mode], CP, FV, X, Y, Z);
	MovePlayerObject(playerid, noclipdata[playerid][flyobject], X, Y, Z, speed);
	noclipdata[playerid][lastmove] = GetTickCount();
	return 1;
}
 
GetNextCameraPosition(move_mode, Float:CP[3], Float:FV[3], &Float:X, &Float:Y, &Float:Z)
{
    #define OFFSET_X (FV[0]*6000.0)
	#define OFFSET_Y (FV[1]*6000.0)
	#define OFFSET_Z (FV[2]*6000.0)
	switch(move_mode)
	{
		case MOVE_FORWARD:
		{
			X = CP[0]+OFFSET_X;
			Y = CP[1]+OFFSET_Y;
			Z = CP[2]+OFFSET_Z;
		}
		case MOVE_BACK:
		{
			X = CP[0]-OFFSET_X;
			Y = CP[1]-OFFSET_Y;
			Z = CP[2]-OFFSET_Z;
		}
		case MOVE_LEFT:
		{
			X = CP[0]-OFFSET_Y;
			Y = CP[1]+OFFSET_X;
			Z = CP[2];
		}
		case MOVE_RIGHT:
		{
			X = CP[0]+OFFSET_Y;
			Y = CP[1]-OFFSET_X;
			Z = CP[2];
		}
		case MOVE_BACK_LEFT:
		{
			X = CP[0]+(-OFFSET_X - OFFSET_Y);
 			Y = CP[1]+(-OFFSET_Y + OFFSET_X);
		 	Z = CP[2]-OFFSET_Z;
		}
		case MOVE_BACK_RIGHT:
		{
			X = CP[0]+(-OFFSET_X + OFFSET_Y);
 			Y = CP[1]+(-OFFSET_Y - OFFSET_X);
		 	Z = CP[2]-OFFSET_Z;
		}
		case MOVE_FORWARD_LEFT:
		{
			X = CP[0]+(OFFSET_X  - OFFSET_Y);
			Y = CP[1]+(OFFSET_Y  + OFFSET_X);
			Z = CP[2]+OFFSET_Z;
		}
		case MOVE_FORWARD_RIGHT:
		{
			X = CP[0]+(OFFSET_X  + OFFSET_Y);
			Y = CP[1]+(OFFSET_Y  - OFFSET_X);
			Z = CP[2]+OFFSET_Z;
		}
	}
}
