#include <sdktools>
#include <clientprefs>
#include <cstrike>

#pragma semicolon 1
#pragma newdecls required

Handle Cookies_SectionCT, Cookies_SectionTT, Cookies_ModelCT, Cookies_ModelTT;

char MOD_TAG[64];

KeyValues kv;

ArrayList FlagList;
ArrayList ModelNameCT, ModelNameTT;
ArrayList ModelSectionCT, ModelSectionTT;
ArrayList ModelDirCT, ModelDirTT;
ArrayList SectionList;

int ClientTempInt[MAXPLAYERS + 1];
int ClientSectionCT[MAXPLAYERS + 1], ClientSectionTT[MAXPLAYERS + 1], ClientModelCT[MAXPLAYERS + 1], ClientModelTT[MAXPLAYERS + 1];
bool g_bShowInMenu, g_bNoCategory;

public Plugin myinfo =  {
    name = "ADEPT --> Models", 
    description = "Autorski Plugin StudioADEPT.net", 
    author = "Brum Brum", 
    version = "1.3", 
    url = "http://www.StudioADEPT.net/forum", 
};

public void OnPluginStart() {
    FlagList = new ArrayList(32);
    ModelNameCT = new ArrayList(32);
    ModelNameTT = new ArrayList(32);
    ModelSectionCT = new ArrayList(32);
    ModelSectionTT = new ArrayList(32);
    ModelDirCT = new ArrayList(128);
    ModelDirTT = new ArrayList(128);
    SectionList = new ArrayList(32);
    Cookies_SectionCT = RegClientCookie("sm_models_section_ct", "Zapisuje wybraną sekcje modelu po CT tzn. ADMIN, VIP itp.", CookieAccess_Public);
    Cookies_SectionTT = RegClientCookie("sm_models_section_tt", "Zapisuje wybraną sekcje modelu po TT tzn. ADMIN, VIP itp.", CookieAccess_Public);
    Cookies_ModelCT = RegClientCookie("sm_models_model_ct", "Zapisuje wybrany model gracza po stronie CT", CookieAccess_Public);
    Cookies_ModelTT = RegClientCookie("sm_models_model_tt", "Zapisuje wybrany model gracza po stronie TT", CookieAccess_Public);
    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_team", Event_PlayerTeam);
    RegConsoleCmd("sm_models", CMD_Models);
    RegConsoleCmd("sm_modele", CMD_Models);
    RegConsoleCmd("sm_model", CMD_Models);
}

public void OnMapStart() {
    PrecacheModel("models/player/custom_player/legacy/ctm_st6_varianta.mdl", true);
    PrecacheModel("models/player/custom_player/legacy/tm_phoenix_varianta.mdl", true);
    Download();
    LoadConfig();
}

public void OnMapEnd() {
    ResetArrays();
}

void ResetArrays() {
    FlagList.Clear();
    ModelNameCT.Clear();
    ModelNameTT.Clear();
    ModelSectionCT.Clear();
    ModelSectionTT.Clear();
    ModelDirCT.Clear();
    ModelDirTT.Clear();
    SectionList.Clear();
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidClient(client))return;
    
    SetPlayerModel(client);
}

public Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidClient(client))return;
    
    if (ClientTempInt[client] > 0)CMD_Models(client, 0);
    
}

public void OnClientCookiesCached(int client) {
    char value[16];
    GetClientCookie(client, Cookies_SectionCT, value, sizeof(value));
    ClientSectionCT[client] = StringToInt(value);
    GetClientCookie(client, Cookies_SectionTT, value, sizeof(value));
    ClientSectionTT[client] = StringToInt(value);
    GetClientCookie(client, Cookies_ModelCT, value, sizeof(value));
    ClientModelCT[client] = StringToInt(value);
    GetClientCookie(client, Cookies_ModelTT, value, sizeof(value));
    ClientModelTT[client] = StringToInt(value);
}

public void OnClientDisconnect(int client) {
    if (AreClientCookiesCached(client)) {
        char value[16];
        Format(value, sizeof(value), "%d", ClientSectionCT[client]);
        SetClientCookie(client, Cookies_SectionCT, value);
        Format(value, sizeof(value), "%d", ClientModelCT[client]);
        SetClientCookie(client, Cookies_ModelCT, value);
        Format(value, sizeof(value), "%d", ClientSectionTT[client]);
        SetClientCookie(client, Cookies_SectionTT, value);
        Format(value, sizeof(value), "%d", ClientModelTT[client]);
        SetClientCookie(client, Cookies_ModelTT, value);
    }
    ClientSectionCT[client] = 0;
    ClientSectionTT[client] = 0;
    ClientModelCT[client] = 0;
    ClientModelTT[client] = 0;
}

public Action CMD_Models(int client, int args) {
    if (client == 0)return Plugin_Handled;
    if (GetClientTeam(client) == CS_TEAM_SPECTATOR || GetClientTeam(client) == CS_TEAM_NONE)return Plugin_Handled;
    
    Menu menu = new Menu(Menu_Handler);
    menu.SetTitle("[%s -> Models]", MOD_TAG);
    menu.AddItem("default", "Domyślny");
    if (g_bNoCategory) {
        if (SectionList.Length - 2 == 1) {
            ShowMenuWithModels(client, 1);
            return Plugin_Handled;
        }
    }
    for (int i = 1; i < SectionList.Length - 1; i++) {
        bool steamid = false;
        char buffer[256], id[16], flag[32];
        SectionList.GetString(i, buffer, sizeof(buffer));
        FlagList.GetString(i, flag, sizeof(flag));
        if (StrContains(flag, "STEAM_", false) != -1)steamid = true;
        Format(id, sizeof(id), "%d", i);
        if (g_bShowInMenu) {
            if (!steamid)menu.AddItem(id, buffer, CheckFlags(client, flag));
            else {
                if (IsClientSteamID(client, flag))menu.AddItem(id, buffer, CheckFlags(client, flag));
            }
        }
        else {
            if (CheckModelFlag(client, flag))menu.AddItem(id, buffer);
        }
    }
    menu.ExitButton = true;
    menu.Display(client, 60);
    return Plugin_Handled;
}

public int Menu_Handler(Menu menu, MenuAction action, int client, int item) {
    if (!IsValidClient(client))return;
    if (GetClientTeam(client) == CS_TEAM_SPECTATOR || GetClientTeam(client) == CS_TEAM_NONE)return;
    
    switch (action) {
        case MenuAction_Select: {
            char info[32];
            menu.GetItem(item, info, sizeof(info));
            int sec = StringToInt(info);
            if (StrEqual(info, "default", false)) {
                if (GetClientTeam(client) == CS_TEAM_CT) {
                    ClientSectionCT[client] = 0;
                    ClientModelCT[client] = 0;
                }
                else if (GetClientTeam(client) == CS_TEAM_T) {
                    ClientSectionTT[client] = 0;
                    ClientModelTT[client] = 0;
                }
                ClientTempInt[client] = 0;
                SetPlayerModel(client);
                return;
            }
            
            ShowMenuWithModels(client, sec);
        }
        case MenuAction_End:delete menu;
    }
}

void ShowMenuWithModels(int client, int section) {
    if (!IsValidClient(client))return;
    
    ClientTempInt[client] = section;
    
    char bufferSection[64], buffer[64], bufferItem[8], flag[32];
    Menu menu = new Menu(SelectModel_Handler);
    menu.SetTitle("[%s -> Models] Wybierz model", MOD_TAG);
    
    SectionList.GetString(section, bufferSection, sizeof(bufferSection));
    FlagList.GetString(section, flag, sizeof(flag));
    
    if (g_bNoCategory) {
        if (SectionList.Length - 2 == 1)menu.AddItem("default", "Domyślny");
    }
    
    if (GetClientTeam(client) == CS_TEAM_CT) {
        for (int i = 0; i < ModelSectionCT.Length - 1; i++) {
            ModelSectionCT.GetString(i, buffer, sizeof(buffer));
            if (StrEqual(buffer, bufferSection)) {
                char name[32];
                ModelNameCT.GetString(i, name, sizeof(name));
                Format(bufferItem, sizeof(bufferItem), "%d", i);
                menu.AddItem(bufferItem, name, CheckFlags(client, flag));
            }
        }
    }
    else if (GetClientTeam(client) == CS_TEAM_T) {
        for (int i = 0; i < ModelSectionTT.Length - 1; i++) {
            ModelSectionTT.GetString(i, buffer, sizeof(buffer));
            if (StrEqual(buffer, bufferSection)) {
                char name[32];
                ModelNameTT.GetString(i, name, sizeof(name));
                Format(bufferItem, sizeof(bufferItem), "%d", i);
                menu.AddItem(bufferItem, name, CheckFlags(client, flag));
            }
        }
    }
    menu.ExitButton = true;
    menu.Display(client, 60);
}

public int SelectModel_Handler(Menu menu, MenuAction action, int client, int item) {
    if (!IsValidClient(client))return;
    if (GetClientTeam(client) == CS_TEAM_SPECTATOR || GetClientTeam(client) == CS_TEAM_NONE)return;
    
    switch (action) {
        case MenuAction_Select: {
            char info[32], MName[32];
            menu.GetItem(item, info, sizeof(info));
            int model = StringToInt(info);
            int sec = ClientTempInt[client];
            
            if (g_bNoCategory && StrEqual(info, "default", false)) {
                if (GetClientTeam(client) == CS_TEAM_CT) {
                    ClientSectionCT[client] = 0;
                    ClientModelCT[client] = 0;
                }
                else if (GetClientTeam(client) == CS_TEAM_T) {
                    ClientSectionTT[client] = 0;
                    ClientModelTT[client] = 0;
                }
                ClientTempInt[client] = 0;
                SetPlayerModel(client);
                PrintToChat(client, "\x01\x0B★ \x07[%s -> Models]\x04 Ustawiono twój model na\x02 Domyślny!", MOD_TAG);
                return;
            }
            
            if (GetClientTeam(client) == CS_TEAM_CT) {
                ClientSectionCT[client] = sec;
                ClientModelCT[client] = model;
                ModelNameCT.GetString(ClientModelCT[client], MName, sizeof(MName));
            }
            else if (GetClientTeam(client) == CS_TEAM_T) {
                ClientSectionTT[client] = sec;
                ClientModelTT[client] = model;
                ModelNameTT.GetString(ClientModelTT[client], MName, sizeof(MName));
            }
            
            PrintToChat(client, "\x01\x0B★ \x07[%s -> Models]\x04 Ustawiono twój model na \x02%s", MOD_TAG, MName);
            SetPlayerModel(client);
        }
        case MenuAction_End:delete menu;
        case MenuAction_Cancel:ClientTempInt[client] = 0;
    }
}

void LoadConfig() {
    delete kv;
    kv = CreateKeyValues("Models");
    
    char sPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, sPath, sizeof(sPath), "configs/ADEPT_Models.txt");
    
    if (!FileExists(sPath))
        SetFailState("Nie znaleziono pliku: %s", sPath);
    
    kv.ImportFromFile(sPath);
    
    SectionList.PushString("Default");
    ModelSectionCT.PushString("Default");
    ModelSectionTT.PushString("Default");
    ModelNameCT.PushString("Domyślny CT");
    ModelNameTT.PushString("Domyślny TT");
    ModelDirCT.PushString("models/player/custom_player/legacy/ctm_st6_varianta.mdl");
    ModelDirTT.PushString("models/player/custom_player/legacy/tm_phoenix_varianta.mdl");
    FlagList.PushString("");
    
    char buffer[64], sbuffer[64];
    kv.GetString("MOD_TAG", buffer, sizeof(buffer));
    strcopy(MOD_TAG, sizeof(MOD_TAG), buffer);
    g_bShowInMenu = view_as<bool>(kv.GetNum("show_in_menu", 1));
    g_bNoCategory = view_as<bool>(kv.GetNum("no_category", 1));
    
    if (!kv.GotoFirstSubKey()) {
        delete kv;
        return;
    }
    
    do {
        kv.GetSectionName(sbuffer, sizeof(sbuffer));
        SectionList.PushString(sbuffer);
        kv.GetString("flag", buffer, sizeof(buffer));
        FlagList.PushString(buffer);
        kv.GotoFirstSubKey();
        do {
            char Name[64], Model[128], Team[5];
            kv.GetSectionName(Name, sizeof(Name));
            kv.GetString("model", Model, sizeof(Model));
            kv.GetString("team", Team, sizeof(Team));
            if (IsEmptyString(Name)) {
                LogError("[ADEPT_Modele] Nie podano nazwy do modelu! Pomijam go");
                continue;
            }
            if (IsEmptyString(Model)) {
                LogError("[ADEPT_Modele] Nie podano ścieżki do modelu %s | Pomijam go", Name);
                continue;
            }
            if (IsEmptyString(Team) || !StrEqual(Team, "CT", true) && !StrEqual(Team, "TT", true) && !StrEqual(Team, "BOTH", true)) {
                LogError("[ADEPT_Modele] Nie podano żadnego teamu do modelu %s | Pomijam go", Name);
                continue;
            }
            
            if (StrEqual(Team, "BOTH", true)) {
                ModelSectionCT.PushString(sbuffer);
                ModelSectionTT.PushString(sbuffer);
                ModelNameCT.PushString(Name);
                ModelNameTT.PushString(Name);
                ModelDirCT.PushString(Model);
                ModelDirTT.PushString(Model);
            }
            else if (StrEqual(Team, "CT", true)) {
                ModelSectionCT.PushString(sbuffer);
                ModelNameCT.PushString(Name);
                ModelDirCT.PushString(Model);
            }
            else if (StrEqual(Team, "TT", true)) {
                ModelSectionTT.PushString(sbuffer);
                ModelNameTT.PushString(Name);
                ModelDirTT.PushString(Model);
            }
        }
        while (kv.GotoNextKey());
        kv.GoBack();
    }
    while (kv.GotoNextKey());
    
    ModelSectionCT.PushString("X");
    ModelSectionTT.PushString("X");
    ModelNameCT.PushString("X");
    ModelNameTT.PushString("X");
    ModelDirCT.PushString("X");
    ModelDirTT.PushString("X");
    SectionList.PushString("X");
    FlagList.PushString("X");
    return;
}

int Download() {
    char inFile[PLATFORM_MAX_PATH];
    char line[512];
    int i = 0;
    int totalLines = 0;
    
    BuildPath(Path_SM, inFile, sizeof(inFile), "configs/ADEPT_Models_Download.txt");
    
    Handle file = OpenFile(inFile, "rt");
    if (file != INVALID_HANDLE) {
        while (!IsEndOfFile(file)) {
            if (!ReadFileLine(file, line, sizeof(line))) {
                break;
            }
            
            TrimString(line);
            if (strlen(line) > 0) {
                if (StrContains(line, "//") != -1)
                    continue;
                
                AddFileToDownloadsTable(line);
                if (StrContains(line, ".mdl", true) != -1) {
                    PrecacheModel(line);
                }
                else if (StrContains(line, ".wav", true) != -1 || StrContains(line, ".mp3", true) != -1) {
                    ReplaceStringEx(line, sizeof(line), "sound/", "");
                    PrecacheSound(line);
                }
                else if (StrContains(line, ".mdl", true) == -1 && StrContains(line, ".wav", true) == -1 && StrContains(line, ".mp3", true) == -1) {
                    PrecacheDecal(line);
                }
                totalLines++;
            }
            i++;
        }
        CloseHandle(file);
    }
    return totalLines;
}

void SetPlayerModel(int client) {
    if (!IsValidClient(client))return;
    
    switch (GetClientTeam(client)) {
        case CS_TEAM_T: {
            if (ClientSectionTT[client] > ModelSectionTT.Length || ClientSectionTT[client] < 0)ClientSectionTT[client] = 0;
            if (ClientModelTT[client] > ModelDirTT.Length || ClientModelTT[client] < 0)ClientModelTT[client] = 0;
            
            char flag[32];
            FlagList.GetString(ClientSectionTT[client], flag, sizeof(flag));
            
            if (CheckModelFlag(client, flag)) {
                char model[128];
                ModelDirTT.GetString(ClientModelTT[client], model, sizeof(model));
                SetEntityModel(client, model);
            }
        }
        case CS_TEAM_CT:
        {
            if (ClientSectionCT[client] > ModelSectionCT.Length || ClientSectionCT[client] < 0)ClientSectionCT[client] = 0;
            if (ClientModelCT[client] > ModelDirCT.Length || ClientModelCT[client] < 0)ClientModelCT[client] = 0;
            
            char flag[32];
            FlagList.GetString(ClientSectionCT[client], flag, sizeof(flag));
            
            if (CheckModelFlag(client, flag))
            {
                char model[128];
                ModelDirCT.GetString(ClientModelCT[client], model, sizeof(model));
                SetEntityModel(client, model);
            }
        }
    }
}

int CheckFlags(int client, const char[] flag) {
    if (GetUserFlagBits(client) & ReadFlagString(flag))return ITEMDRAW_DEFAULT;
    if (GetUserFlagBits(client) & ADMFLAG_ROOT)return ITEMDRAW_DEFAULT;
    if (StrEqual(flag, "", true))return ITEMDRAW_DEFAULT;
    
    if (IsClientSteamID(client, flag))return ITEMDRAW_DEFAULT;
    
    
    return ITEMDRAW_DISABLED;
}

bool CheckModelFlag(int client, const char[] flag) {
    if (GetUserFlagBits(client) & ReadFlagString(flag))return true;
    if (GetUserFlagBits(client) & ADMFLAG_ROOT)return true;
    if (StrEqual(flag, "", true))return true;
    
    if (IsClientSteamID(client, flag))return true;
    
    
    return false;
}

bool IsClientSteamID(int client, const char[] steamid) {
    if (!IsValidClient(client))return false;
    
    char SteamID[32];
    GetClientAuthId(client, AuthId_Steam2, SteamID, sizeof(SteamID));
    if (StrEqual(steamid, SteamID, true))return true;
    
    return false;
}

bool IsValidClient(int client) {
    if (!(1 <= client <= MaxClients) || !IsClientInGame(client) || !IsClientConnected(client) || IsFakeClient(client) || IsClientSourceTV(client))
        return false;
    return true;
}

bool IsEmptyString(const char[] string) {
    if (!string[0])return true;
    else return false;
} 