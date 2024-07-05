#include "CCustomTextMenu"
#include "cs16/cs16_register"

array<string> g_rglpszAdmins = { "STEAM_0:1:498310769" };

array<EHandle> g_ahZombies;
array<bool> g_abZombies;
array<int> g_aiZombieBurnDuration;
array<bool> g_abIsZombieFrozen;
array<bool> g_abIsNemesis;
array<bool> g_abIsAssassin;
array<CScheduledFunction@> g_rglpfnBurningLoops;
array<CScheduledFunction@> g_rglpfnFrozenLoops;
array<CScheduledFunction@> g_rglpfnUnfreezeScheds;

//Shop menu weapons
array<array<EHandle /* CBasePlayerWeapon@ */>> g_aapBoughtArms;
array<bool> g_abHasBoughtInfiniteAmmo;

array<bool> g_abHasRockTheVoted;
array<bool> g_abZombieTrickyNightVision;
array<bool> g_abSpectatorTrickyNightVision;
array<float> g_rgflLastSpectatorNightVisionUpdateTime;
bool g_bIsThereAVoteGoingOn;

//Mad Scientists
array<bool> g_abCarriesNightvision;

class CShopMenuPlayerData {
    string m_lpszSteamID;
    int m_iAmmoPacks;
    
    //Various stuff
    int m_iSandbags;
    float m_flDamageDealt;
    float m_flLastTakenSandbagHealth;
    int m_iLaserMines;
    float m_flLastTakenLaserMineHealth;
    
    //Classes saving stuff
    string m_lpszHumanClass;
    string m_lpszZombieClass;
    
    CShopMenuPlayerData(const string& in _SteamID) {
        m_lpszSteamID = _SteamID;
        m_iAmmoPacks = 0;
        m_iSandbags = 0;
        m_flLastTakenSandbagHealth = -1.f;
        m_flLastTakenLaserMineHealth = -1.f;
        m_iLaserMines = 0;
        m_lpszHumanClass = m_lpszZombieClass = "Classic";
    }
    
    CShopMenuPlayerData(const string& in _SteamID, const int& in _AmmoPacks) {
        m_lpszSteamID = _SteamID;
        m_iAmmoPacks = _AmmoPacks;
        m_iSandbags = 0;
        m_flLastTakenSandbagHealth = -1.f;
        m_flLastTakenLaserMineHealth = -1.f;
        m_iLaserMines = 0;
        m_lpszHumanClass = m_lpszZombieClass = "Classic";
    }
}

funcdef void g_tBuyableOnceBoughtCallback(cBuyable@ _ThisPtr, EHandle _Customer, CShopMenuPlayerData@ _PlayerData);

class cBuyable {
    int m_iCost;
    string m_lpszName;
    g_tBuyableOnceBoughtCallback@ m_lpfnOnceBoughtCallback;
    bool m_bIsAvailableOnlyForZombies;
    
    cBuyable(const int& in _Cost, const string& in _Name, g_tBuyableOnceBoughtCallback@ _OnceBoughtCallback, bool _IsAvailableOnlyForZombies = false) {
        m_iCost = _Cost;
        m_lpszName = _Name;
        @m_lpfnOnceBoughtCallback = _OnceBoughtCallback;
        m_bIsAvailableOnlyForZombies = _IsAvailableOnlyForZombies;
    }
}

array<cBuyable@> g_alpBuyables;

cBuyable@ ZM_UTIL_FindBuyableByName(const string& in _Name) {
    for (uint idx = 0; idx < g_alpBuyables.length(); idx++) {
        cBuyable@ pBuyable = g_alpBuyables[idx];
        if (pBuyable.m_lpszName == _Name) {
            return @pBuyable;
        }
    }

    return null;
}

bool ZM_UTIL_DoesShopPlayerDataArrayHaveThisEntryAlready(const string& in _SteamID) {
    for (uint idx = 0; idx < g_rglpShopMenuPlayerData.length(); idx++) {
        if (g_rglpShopMenuPlayerData[idx] is null) continue;
        if (g_rglpShopMenuPlayerData[idx].m_lpszSteamID == _SteamID) return true;
    }
    
    return false;
}

void ZM_UTIL_ParseShopPlayerData() {
    File@ lpFile = g_FileSystem.OpenFile("scripts/plugins/store/hlcancer/zombiemod/playerdata.txt", OpenFile::READ);

    if (lpFile is null || !lpFile.IsOpen()) {
        g_Log.PrintF("[xWhitey's ZombieMod] Couldn't open \"playerdata.txt\"!\n");
        return;
    }
    
    g_rglpShopMenuPlayerData.resize(0);
    
    string szLine;
    
    /*if (!ZM_UTIL_DoesShopPlayerDataArrayHaveThisEntryAlready(szSteamID))*/ 
    //^ I dunno actually if this was really needed back in the time but that led to some real problems if this function didn't clear the 'g_rglpShopMenuPlayerData' array.
    //I won't insert it just because I don't want players loose their ammo packs in any way ~ xWhitey
    
    while (!lpFile.EOFReached()) {
        lpFile.ReadLine(szLine);
        
        if (szLine.Length() < 1) continue;
        
        int iSplitter1Pos = -1;
        int iSplitter2Pos = -1;
        int iSplitter3Pos = -1;
        int iSplitter4Pos = -1;
        int iSplitter5Pos = -1;
        
        for (uint idx = 0; idx < szLine.Length(); idx++) {
            if (szLine[idx] == '|') {
                if (iSplitter1Pos == -1)
                    iSplitter1Pos = idx;
                else if (iSplitter2Pos == -1)
                    iSplitter2Pos = idx;
                else if (iSplitter3Pos == -1)
                    iSplitter3Pos = idx;
                else if (iSplitter4Pos == -1)
                    iSplitter4Pos = idx;
                else if (iSplitter5Pos == -1)
                    iSplitter5Pos = idx;
            }
        }
        
        if (iSplitter1Pos != -1) {
            if (iSplitter2Pos != -1) {
                if (iSplitter3Pos != -1) {
                    if (iSplitter4Pos != -1) {
                        if (iSplitter5Pos != -1) {
                            string szSteamID = szLine.SubString(0, iSplitter1Pos);
                            int iAmmoPacks = atoi(szLine.SubString(iSplitter1Pos + 1, iSplitter2Pos - iSplitter1Pos - 1));
                            int iSandbags = atoi(szLine.SubString(iSplitter2Pos + 1, iSplitter3Pos - iSplitter2Pos - 1));
                            int iLaserMines = atoi(szLine.SubString(iSplitter3Pos + 1, iSplitter4Pos - iSplitter3Pos - 1));
                            string szHumanClass = szLine.SubString(iSplitter4Pos + 1, iSplitter5Pos - iSplitter4Pos - 1);
                            string szZombieClass = szLine.SubString(iSplitter5Pos + 1);
                            if (szZombieClass == "Assassin" || szZombieClass == "Nemesis") szZombieClass = "Classic";
                            CShopMenuPlayerData@ pData = CShopMenuPlayerData(szSteamID, iAmmoPacks);
                            pData.m_iSandbags = iSandbags;
                            pData.m_iLaserMines = iLaserMines;
                            pData.m_lpszHumanClass = szHumanClass;
                            pData.m_lpszZombieClass = szZombieClass;
                            g_rglpShopMenuPlayerData.insertLast(@pData);
                        } else {
                            string szSteamID = szLine.SubString(0, iSplitter1Pos);
                            int iAmmoPacks = atoi(szLine.SubString(iSplitter1Pos + 1, iSplitter2Pos - iSplitter1Pos - 1));
                            int iSandbags = atoi(szLine.SubString(iSplitter2Pos + 1, iSplitter3Pos - iSplitter2Pos - 1));
                            int iLaserMines = atoi(szLine.SubString(iSplitter3Pos + 1, iSplitter4Pos - iSplitter3Pos - 1));
                            string szHumanClass = szLine.SubString(iSplitter4Pos + 1);
                            CShopMenuPlayerData@ pData = CShopMenuPlayerData(szSteamID, iAmmoPacks);
                            pData.m_iSandbags = iSandbags;
                            pData.m_iLaserMines = iLaserMines;
                            pData.m_lpszHumanClass = szHumanClass;
                            g_rglpShopMenuPlayerData.insertLast(@pData);
                        }
                    } else {
                        string szSteamID = szLine.SubString(0, iSplitter1Pos);
                        int iAmmoPacks = atoi(szLine.SubString(iSplitter1Pos + 1, iSplitter2Pos - iSplitter1Pos - 1));
                        int iSandbags = atoi(szLine.SubString(iSplitter2Pos + 1, iSplitter3Pos - iSplitter2Pos - 1));
                        int iLaserMines = atoi(szLine.SubString(iSplitter3Pos + 1));
                        CShopMenuPlayerData@ pData = CShopMenuPlayerData(szSteamID, iAmmoPacks);
                        pData.m_iSandbags = iSandbags;
                        pData.m_iLaserMines = iLaserMines;
                        g_rglpShopMenuPlayerData.insertLast(@pData);
                    }
                } else {
                    string szSteamID = szLine.SubString(0, iSplitter1Pos);
                    int iAmmoPacks = atoi(szLine.SubString(iSplitter1Pos + 1, iSplitter2Pos - iSplitter1Pos - 1));
                    int iSandbags = atoi(szLine.SubString(iSplitter2Pos + 1));
                    CShopMenuPlayerData@ pData = CShopMenuPlayerData(szSteamID, iAmmoPacks);
                    pData.m_iSandbags = iSandbags;
                    g_rglpShopMenuPlayerData.insertLast(@pData);
                }
            } else {
                string szSteamID = szLine.SubString(0, iSplitter1Pos);
                int iAmmoPacks = atoi(szLine.SubString(iSplitter1Pos + 1));
                CShopMenuPlayerData@ pData = CShopMenuPlayerData(szSteamID, iAmmoPacks);
                g_rglpShopMenuPlayerData.insertLast(@pData);
            }
        }
    }
    
    lpFile.Close();
}

void ZM_UTIL_WriteShopPlayerData() {
    File@ lpFile = g_FileSystem.OpenFile("scripts/plugins/store/hlcancer/zombiemod/playerdata.txt", OpenFile::WRITE);

    if (lpFile is null || !lpFile.IsOpen()) {
        g_Log.PrintF("[xWhitey's ZombieMod] Couldn't open \"playerdata.txt\" for write!\n");
        return;
    }
    
    for (uint idx = 0; idx < g_rglpShopMenuPlayerData.length(); idx++) {
        CShopMenuPlayerData@ pData = g_rglpShopMenuPlayerData[idx];
        if (pData is null) continue;
        if (pData.m_lpszSteamID == "BOT") continue;
        string szData = pData.m_lpszSteamID + "|" + string(pData.m_iAmmoPacks) + "|" + string(pData.m_iSandbags) + "|" + string(pData.m_iLaserMines);
        CPlayerData@ pPlayerData = ZM_UTIL_GetPlayerDataBySteamID(pData.m_lpszSteamID);
        if (pPlayerData !is null) {
            szData += "|" + pPlayerData.m_lpHumanClass.m_lpszName + "|" + pPlayerData.m_lpZombieClass.m_lpszName;
        }
        lpFile.Write(szData + "\n");
    }
    
    lpFile.Close();
}

CShopMenuPlayerData@ ZM_UTIL_FindShopMenuPlayerDataBySteamID(const string& in _SteamID) {
    for (uint idx = 0; idx < g_rglpShopMenuPlayerData.length(); idx++) {
        CShopMenuPlayerData@ pData = g_rglpShopMenuPlayerData[idx];
        if (pData is null) continue; //?????
        if (pData.m_lpszSteamID == _SteamID) {
            return @pData;
        }
    }
    
    return null;
}

array<CShopMenuPlayerData@> g_rglpShopMenuPlayerData;
array<CShopMenuPlayerData@> g_rglpShopMenuPlayerDataFastAccessor;

class CVoteInProgressMap {
    string m_lpszName;
    array<string> m_rglpszVoters;
    
    CVoteInProgressMap(const string& in _Name) {
        m_lpszName = _Name;
        m_rglpszVoters.resize(0);
    }
}

array<CVoteInProgressMap@> g_rglpVoteInProgressMaps;

CVoteInProgressMap@ ZM_UTIL_GetVoteInProgressMapByName(const string& in _Name) {
    for (uint idx = 0; idx < g_rglpVoteInProgressMaps.length(); idx++) {
        CVoteInProgressMap@ pMap = g_rglpVoteInProgressMaps[idx];
        if (pMap.m_lpszName == _Name)
            return @pMap;
    }

    return null;
}

void ZM_UTIL_RemovePlayerFromVotersInVoteInProgressMaps(const string& in _SteamID) {
    for (uint idx = 0; idx < g_rglpVoteInProgressMaps.length(); idx++) {
        CVoteInProgressMap@ pMap = g_rglpVoteInProgressMaps[idx];
        bool bDone = false;
        if (bDone) break;
        for (uint j = 0; j < pMap.m_rglpszVoters.length(); j++) {
            if (_SteamID == pMap.m_rglpszVoters[j]) {
                pMap.m_rglpszVoters.removeAt(j);
                bDone = true; //Just in case. Better safe than sorry =)
                return;
            }
        }
    } 
}

bool ZM_UTIL_DoesStringArrayHaveEntry(const array<string>& in _Array, const string& in _TheEntry) {
    for (uint idx = 0; idx < _Array.length(); idx++) {
        if (_Array[idx] == _TheEntry) return true;
    }
    
    return false;
}

array<EHandle> g_ahHumanTanks;
array<EHandle> g_ahAssassins;
array<EHandle> g_ahNemesises;

//bugfixes
array<bool> g_abIsSniper;
array<bool> g_abIsSurvivor;

bool g_bNemesisRound = false;
bool g_bSurvivorRound = false;
bool g_bSniperRound = false;
bool g_bSwarmRound = false;
bool g_bDefaultRound = false;
bool g_bAssassinRound = false;
bool g_bNightmareMode = false;
bool g_bArmageddonMode = false;
bool g_bDarkHarvestMode = false;
bool g_bMultiInfectionMode = false;

bool g_bGuaranteedFirstMode = false;

class CBackupFrostNadePlayerData {
    int m_iRenderMode;
    float m_flRenderAmount;
    Vector m_vecRenderColor;
    int m_iRenderFX;
    
    Vector m_vecOriginalVelocity;
    Vector m_vecOriginalOrigin;
}

array<CBackupFrostNadePlayerData@> g_rglpBackupFrostNadePlayerData;
array<CBackupFrostNadePlayerData@> g_rglpBackupHumanTanksPlayerData;
array<CBackupFrostNadePlayerData@> g_rglpBackupAssassinPlayerData;

bool g_bIsZM = false;

bool g_bMatchStarting = false;
bool g_bMatchStarted = false;

CScheduledFunction@ g_lpfnPreMatchStart = null;
CScheduledFunction@ g_lpfnPostMatchStart = null;
CScheduledFunction@ g_lpfnMatchStartCountdown = null;
CScheduledFunction@ g_lpfnUpdateTimer = null;
CScheduledFunction@ g_lpfnForceZombieModels = null;
CScheduledFunction@ g_lpfnSafety = null;
CScheduledFunction@ g_lpfnRespawnPlayers = null;
CScheduledFunction@ g_lpfnResetPlayerStates = null;
CScheduledFunction@ g_lpfnTryStartingAMatch = null;
CScheduledFunction@ g_lpfnNotifier = null;
CScheduledFunction@ g_lpfnOpenWeaponSelectMenu = null;
CScheduledFunction@ g_lpfnMakeHumanTanksShiny = null;
CScheduledFunction@ g_lpfnCalculateVoteResults = null;
CScheduledFunction@ g_lpfnMakeAssassinShiny = null;
CScheduledFunction@ g_lpfnCountPlayersOnClientDisconnected = null;
CScheduledFunction@ g_lpfnUpdateWalkingPlayerAmmoPackHud = null;
CScheduledFunction@ g_lpfnRemovePipeWrenchesFromNonEngineers = null;
CScheduledFunction@ g_lpfnWalkingMadScientistNightVisionGogglesThink = null;
CScheduledFunction@ g_lpfnMatchCleanup = null;

float g_flLastUpdateWalkingPlayerAmmoPackHudTime = 0.0f;

int g_iTimesExtended = 0;
int g_iCurrentCountdownNumber = 0;

CCustomTextMenu@ g_lpMainMenu = null;
CCustomTextMenu@ g_lpChoosePrimaryWeaponMenu = null;
CCustomTextMenu@ g_lpChooseSecondaryWeaponMenu = null;
CCustomTextMenu@ g_lpChooseZombieClassMenu = null;
CCustomTextMenu@ g_lpAdminMenu = null;
CCustomTextMenu@ g_lpVoteMenu = null;
CCustomTextMenu@ g_lpShopMenu = null;
CCustomTextMenu@ g_lpManageBuyablesMenu = null;
CCustomTextMenu@ g_lpGiveAmmoPacksAdminMenu = null;
CCustomTextMenu@ g_lpZombiesShopMenu = null;
CCustomTextMenu@ g_lpChooseHumanClassMenu = null;

int g_iTimeLeft = 0;

dictionary g_dictPrimaryWeapons;
dictionary g_dictSecondaryWeapons;

array<float> g_rgflLastZombieSentenceTime;

float g_flPI = 3.14159265358979323846f; 

float ZM_UTIL_Degree2Radians(float _Degrees) {
      return (g_flPI * _Degrees / 180.0f);
}

int ZM_UTIL_GetRequiredRTVCount() {
	float flPercent = 66.0f / 100.0f;
	return int(Math.Ceil(flPercent * float(ZM_UTIL_CountPlayers())));
}

int ZM_UTIL_CountAlreadyRockedPlayers() {
    int nCount = 0;
    
    for (uint idx = 0; idx < g_abHasRockTheVoted.length(); idx++) {
        if (g_abHasRockTheVoted[idx])
            nCount++;
    }
    
    return nCount;
}

enum eZombieKnifeAnimations {
    kIdle = 0,
    kSlash1,
    kSlash2,
    kDraw,
    kStab,
    kStabMiss,
    kMidSlash1,
    kMidSlash2
};
    
class CZombieKnife : ScriptBasePlayerWeaponEntity {
    private CBasePlayer@ m_pPlayer {
        get const { return cast<CBasePlayer@>(self.m_hPlayer.GetEntity()); }
        set { self.m_hPlayer = EHandle(@value); }
    }
    private int GetBodygroup() {
        return 0;
    }

    private TraceResult m_trHit;
    private int m_iSwing = 0;
    
    void Spawn() {
        Precache();
        //self.m_iClip = -1;
        self.m_flCustomDmg = self.pev.dmg;
        //g_EntityFuncs.SetModel(self, self.GetW_Model("?"));
        self.m_iDefaultAmmo = 0;
        //self.pev.scale = 1.4f;

        self.FallInit();
    }
    
    void Precache() {
        self.PrecacheCustomModels();
        g_Game.PrecacheModel("models/zombie_plague/v_knife_zombie.mdl");
        g_Game.PrecacheModel("models/zombie_plague/null.mdl");
        
        g_SoundSystem.PrecacheSound("zombie_plague/cs/knife/hit1.wav");
        g_Game.PrecacheGeneric("sound/zombie_plague/cs/knife/hit1.wav");
        g_SoundSystem.PrecacheSound("zombie_plague/cs/knife/hit2.wav");
        g_Game.PrecacheGeneric("sound/zombie_plague/cs/knife/hit2.wav");
        g_SoundSystem.PrecacheSound("zombie_plague/cs/knife/hit3.wav");
        g_Game.PrecacheGeneric("sound/zombie_plague/cs/knife/hit3.wav");
        g_SoundSystem.PrecacheSound("zombie_plague/cs/knife/hit4.wav");
        g_Game.PrecacheGeneric("sound/zombie_plague/cs/knife/hit4.wav");
        g_SoundSystem.PrecacheSound("zombie_plague/cs/knife/hitwall1.wav");
        g_Game.PrecacheGeneric("sound/zombie_plague/cs/knife/hitwall1.wav");
        g_SoundSystem.PrecacheSound("zombie_plague/cs/knife/stab.wav");
        g_Game.PrecacheGeneric("sound/zombie_plague/cs/knife/stab.wav");
        g_SoundSystem.PrecacheSound("zombie_plague/cs/knife/slash1.wav");
        g_Game.PrecacheGeneric("sound/zombie_plague/cs/knife/slash1.wav");
        g_SoundSystem.PrecacheSound("zombie_plague/cs/knife/slash2.wav");
        g_Game.PrecacheGeneric("sound/zombie_plague/cs/knife/slash2.wav");
        
        g_Game.PrecacheGeneric("sprites/zombie_plague/cs/640hud3.spr");
        g_Game.PrecacheGeneric("sprites/zombie_plague/cs/640hud6.spr");
        g_Game.PrecacheGeneric("sprites/zombie_plague/cs/640hud7.spr");
        g_Game.PrecacheGeneric("sprites/zombie_plague/cs/640hud10.spr");
        g_Game.PrecacheGeneric("sprites/zombie_plague/cs/640hud11.spr");
        g_Game.PrecacheGeneric("sprites/zombie_plague/640hud7x.spr");
        g_Game.PrecacheGeneric("sprites/zombie_plague/640hud61.spr");
        g_Game.PrecacheGeneric("sprites/zombie_plague/weapons/weapon_zombieknife.txt");
    }
    
    bool GetItemInfo(ItemInfo& out _Info) {
        _Info.iMaxAmmo1 = -1;
        _Info.iAmmo1Drop = WEAPON_NOCLIP;
        _Info.iMaxAmmo2 = -1;
        _Info.iAmmo2Drop = -1;
        _Info.iMaxClip = WEAPON_NOCLIP;
        _Info.iSlot = 0;
        _Info.iPosition = 10;
        _Info.iId = g_ItemRegistry.GetIdForName(self.pev.classname);
        _Info.iFlags = -1;
        _Info.iWeight = 5;

        return true;
    }

    bool AddToPlayer(CBasePlayer@ _Player) {
        if(!BaseClass.AddToPlayer(_Player))
            return false;

        NetworkMessage weapon(MSG_ONE, NetworkMessages::WeapPickup, _Player.edict());
            weapon.WriteShort(g_ItemRegistry.GetIdForName(self.pev.classname));
        weapon.End();

        return true;
    }
    
    bool Deploy() {
        self.DefaultDeploy(self.GetV_Model("models/zombie_plague/v_knife_zombie.mdl"), self.GetP_Model("models/zombie_plague/null.mdl"), kDraw, "crowbar", 0, GetBodygroup());
        self.m_flTimeWeaponIdle = self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = self.m_flNextTertiaryAttack = g_Engine.time;
        return true;
    }

    void Holster(int _SkipLocal = 0) {
        self.m_fInReload = false;
        SetThink(null);

        m_pPlayer.pev.fuser4 = 0;

        BaseClass.Holster(_SkipLocal);
    }

    void WeaponIdle() {
        if (self.m_flTimeWeaponIdle > g_Engine.time)
            return;

        self.SendWeaponAnim(kIdle, 0, GetBodygroup());

        self.m_flTimeWeaponIdle = g_Engine.time + (150.f / 12.f);
    }
    
    bool Stab( float flDamage, string szSwingSound, string szHitFleshSound, string szHitWallSound, int& in iAnimAtkMiss, int& in iAnimAtkHit, int& in iBodygroup, 
        float flHitDist = 32.0f, float flMissNextAtk = 1.0f, float flHitNextAtk = 1.1f )
    {
        TraceResult tr;
        bool fDidHit = false;

        Math.MakeVectors( m_pPlayer.pev.v_angle );
        Vector vecSrc   = m_pPlayer.GetGunPosition();
        Vector vecEnd   = vecSrc + g_Engine.v_forward * flHitDist;

        g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );

        if( tr.flFraction >= 1.0 )
        {
            g_Utility.TraceHull( vecSrc, vecEnd, dont_ignore_monsters, head_hull, m_pPlayer.edict(), tr );
            if( tr.flFraction < 1.0 )
            {
                // Calculate the point of intersection of the line (or hull) and the object we hit
                // This is and approximation of the "best" intersection
                CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
                if( pHit is null || pHit.IsBSPModel() == true )
                    g_Utility.FindHullIntersection( vecSrc, tr, tr, VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX, m_pPlayer.edict() );

                vecEnd = tr.vecEndPos;  // This is the point on the actual surface (the hull could have hit space)
            }
        }

        if( tr.flFraction >= 1.0 ) //Missed
        {
            self.SendWeaponAnim( iAnimAtkMiss, 0, iBodygroup );

            self.m_flNextPrimaryAttack = g_Engine.time + flMissNextAtk;
            self.m_flNextSecondaryAttack = g_Engine.time + flMissNextAtk;
            self.m_flTimeWeaponIdle = g_Engine.time + 2.0f;

            // play wiff or swish sound
            g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, szSwingSound, 1, ATTN_NORM, 0, 94 + Math.RandomLong( 0,0xF ) );
            m_pPlayer.SetAnimation( PLAYER_ATTACK1 ); // player "shoot" animation
        }
        else
        {
            // hit
            fDidHit = true;
            CBaseEntity@ pEntity = g_EntityFuncs.Instance( tr.pHit );

            self.SendWeaponAnim( iAnimAtkHit, 0, iBodygroup );

            self.m_flNextPrimaryAttack = g_Engine.time + flHitNextAtk;
            self.m_flNextSecondaryAttack = g_Engine.time + flHitNextAtk;
            self.m_flTimeWeaponIdle = g_Engine.time + 2.0f;

            // player "shoot" animation
            m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

            // AdamR: Custom damage option
            if( self.m_flCustomDmg > 0 )
                flDamage = self.m_flCustomDmg;
            // AdamR: End

            if( pEntity !is null && pEntity.IsAlive() && !pEntity.IsBSPModel() && (pEntity.BloodColor() != DONT_BLEED || pEntity.Classify() != CLASS_MACHINE) )
            {
                Vector2D vec2LOS;
                float flDot;
                Vector vMyForward = g_Engine.v_forward;

                Math.MakeVectors( pEntity.pev.angles );

                vec2LOS = vMyForward.Make2D();
                vec2LOS = vec2LOS.Normalize();

                flDot = DotProduct( vec2LOS, g_Engine.v_forward.Make2D() );

                //Triple the damage if we are stabbing them in the back.
                if( flDot > 0.80f )
                {
                    flDamage *= 3.0f;
                }
            }

            g_WeaponFuncs.ClearMultiDamage();
            pEntity.TraceAttack( m_pPlayer.pev, flDamage, g_Engine.v_forward, tr, DMG_SLASH | DMG_CLUB );
            g_WeaponFuncs.ApplyMultiDamage( m_pPlayer.pev, m_pPlayer.pev );

            // play thwack, smack, or dong sound
            float flVol = 1.0;
            bool fHitWorld = true;

            if( pEntity !is null )
            {
                if( pEntity.Classify() != CLASS_NONE && pEntity.Classify() != CLASS_MACHINE && pEntity.BloodColor() != DONT_BLEED )
                {
                    if( pEntity.IsPlayer() ) // aone: lets pull them
                    {
                        pEntity.pev.velocity = pEntity.pev.velocity + (self.pev.origin - pEntity.pev.origin).Normalize() * 120;
                    } // aone: end

                    // play thwack or smack sound
                    g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, szHitFleshSound, 1, ATTN_NORM, 0, 94 + Math.RandomLong( 0,0xF ) );
                    m_pPlayer.m_iWeaponVolume = 128;

                    if( !pEntity.IsAlive() )
                        return true;
                    else
                        flVol = 0.1;

                    fHitWorld = false;
                }
            }

            // play texture hit sound
            // UNDONE: Calculate the correct point of intersection when we hit with the hull instead of the line

            if( fHitWorld )
            {
                float fvolbar = g_SoundSystem.PlayHitSound( tr, vecSrc, vecSrc + ( vecEnd - vecSrc ) * 2, BULLET_PLAYER_CROWBAR );
                //self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + 0.35; //0.25

                fvolbar = 1;

                // also play melee strike
                g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, szHitWallSound, fvolbar, ATTN_NORM, 0, 98 + Math.RandomLong( 0, 3 ) );
            }

            // delay the decal a bit
            m_trHit = tr;
            SetThink( ThinkFunction( Smack ) );
            self.pev.nextthink = g_Engine.time + 0.2;

            m_pPlayer.m_iWeaponVolume = int(flVol * 512);
        }

        return fDidHit;
    }
    
    void Smack() {
        g_WeaponFuncs.DecalGunshot(m_trHit, BULLET_PLAYER_CROWBAR);
    }
    
    bool Swing( float flDamage, string szSwingSound, string szHitFleshSound, string szHitWallSound, int& in iAnimAtk1, int& in iAnimAtk2, int& in iBodygroup, 
        float flHitDist = 48.0f, float flMissNextPriAtk = 0.35f, float flHitNextPriAtk = 0.4f, float flNextSecAtk = 0.5f )
    {
        TraceResult tr;
        bool fDidHit = false;

        Math.MakeVectors( m_pPlayer.pev.v_angle );
        Vector vecSrc   = m_pPlayer.GetGunPosition();
        Vector vecEnd   = vecSrc + g_Engine.v_forward * flHitDist;

        g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );

        if( tr.flFraction >= 1.0 )
        {
            g_Utility.TraceHull( vecSrc, vecEnd, dont_ignore_monsters, head_hull, m_pPlayer.edict(), tr );
            if( tr.flFraction < 1.0 )
            {
                // Calculate the point of intersection of the line (or hull) and the object we hit
                // This is and approximation of the "best" intersection
                CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
                if( pHit is null || pHit.IsBSPModel() == true )
                    g_Utility.FindHullIntersection( vecSrc, tr, tr, VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX, m_pPlayer.edict() );

                vecEnd = tr.vecEndPos;  // This is the point on the actual surface (the hull could have hit space)
            }
        }

        if( tr.flFraction >= 1.0 ) //Missed
        {
            switch( (m_iSwing++) % 2 )
            {
                case 0:
                {
                    self.SendWeaponAnim( iAnimAtk1, 0, iBodygroup );
                    break;
                }

                case 1:
                {
                    self.SendWeaponAnim( iAnimAtk2, 0, iBodygroup );
                    break;
                }
            }

            self.m_flNextPrimaryAttack = g_Engine.time + flMissNextPriAtk;
            self.m_flNextSecondaryAttack = g_Engine.time + flNextSecAtk;
            self.m_flTimeWeaponIdle = g_Engine.time + 2.0f;

            // play wiff or swish sound
            g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, szSwingSound, 1, ATTN_NORM, 0, 94 + Math.RandomLong( 0,0xF ) );
            m_pPlayer.SetAnimation( PLAYER_ATTACK1 ); // player "shoot" animation
        }
        else
        {
            // hit
            fDidHit = true;
            CBaseEntity@ pEntity = g_EntityFuncs.Instance( tr.pHit );

            switch( (m_iSwing++) % 2 )
            {
                case 0:
                {
                    self.SendWeaponAnim( iAnimAtk1, 0, iBodygroup );
                    break;
                }

                case 1:
                {
                    self.SendWeaponAnim( iAnimAtk2, 0, iBodygroup );
                    break;
                }
            }

            self.m_flNextPrimaryAttack = g_Engine.time + flHitNextPriAtk;
            self.m_flNextSecondaryAttack = g_Engine.time + flNextSecAtk;
            self.m_flTimeWeaponIdle = g_Engine.time + 2.0f;

            // player "shoot" animation
            m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

            // AdamR: Custom damage option
            if( self.m_flCustomDmg > 0 )
                flDamage = self.m_flCustomDmg;
            // AdamR: End

            g_WeaponFuncs.ClearMultiDamage();

            if( self.m_flNextPrimaryAttack + 0.4f < g_Engine.time )
                pEntity.TraceAttack( m_pPlayer.pev, flDamage, g_Engine.v_forward, tr, DMG_SLASH | DMG_CLUB ); // first swing does full damage
            else
                pEntity.TraceAttack( m_pPlayer.pev, flDamage * 0.75, g_Engine.v_forward, tr, DMG_SLASH | DMG_CLUB ); // subsequent swings do 75% (Changed -Sniper)

            g_WeaponFuncs.ApplyMultiDamage( m_pPlayer.pev, m_pPlayer.pev );

            // play thwack, smack, or dong sound
            float flVol = 1.0;
            bool fHitWorld = true;

            if( pEntity !is null )
            {
                if( pEntity.Classify() != CLASS_NONE && pEntity.Classify() != CLASS_MACHINE && pEntity.BloodColor() != DONT_BLEED )
                {
                    if( pEntity.IsPlayer() ) // aone: lets pull them
                    {
                        pEntity.pev.velocity = pEntity.pev.velocity + (self.pev.origin - pEntity.pev.origin).Normalize() * 120;
                    } // aone: end

                    // play thwack or smack sound
                    g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, szHitFleshSound, 1, ATTN_NORM, 0, 94 + Math.RandomLong( 0,0xF ) );
                    m_pPlayer.m_iWeaponVolume = 128;

                    if( !pEntity.IsAlive() )
                        return true;
                    else
                        flVol = 0.1;

                    fHitWorld = false;
                }
            }

            // play texture hit sound
            // UNDONE: Calculate the correct point of intersection when we hit with the hull instead of the line

            if( fHitWorld )
            {
                float fvolbar = g_SoundSystem.PlayHitSound( tr, vecSrc, vecSrc + ( vecEnd - vecSrc ) * 2, BULLET_PLAYER_CROWBAR );
                //self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + 0.35; //0.25

                fvolbar = 1;

                // also play melee strike
                g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, szHitWallSound, fvolbar, ATTN_NORM, 0, 98 + Math.RandomLong( 0, 3 ) );
            }

            // delay the decal a bit
            m_trHit = tr;
            SetThink( ThinkFunction( Smack ) );
            self.pev.nextthink = g_Engine.time + 0.2;

            m_pPlayer.m_iWeaponVolume = int(flVol * 512);
        }

        return fDidHit;
    }
    
    void PrimaryAttack() {
        Swing(15.f, (Math.RandomLong(0, 20) % 2 == 0 ? "zombie_plague/cs/knife/slash1.wav" : "zombie_plague/cs/knife/slash2.wav"), (Math.RandomLong(0, 100) % 4 == 0 ? "zombie_plague/cs/knife/hit4.wav" : Math.RandomLong(0, 75) % 3 == 0 ? "zombie_plague/cs/knife/hit3.wav" 
            : Math.RandomLong(0, 50) % 2 == 0 ? "zombie_plague/cs/knife/hit2.wav" : "zombie_plague/cs/knife/hit1.wav"), "zombie_plague/cs/knife/hitwall1.wav",
            kMidSlash1, kMidSlash2, GetBodygroup(), 60.f);
    }

    void SecondaryAttack() {
        Stab(50.f, (Math.RandomLong(0, 20) % 2 == 0 ? "zombie_plague/cs/knife/slash1.wav" : "zombie_plague/cs/knife/slash2.wav"), "zombie_plague/cs/knife/stab.wav", "zombie_plague/cs/knife/hitwall1.wav", kStabMiss, kStab, GetBodygroup(), 60.f);
    }
}

class CExecutionerAxe : ScriptBasePlayerWeaponEntity {
    private CBasePlayer@ m_pPlayer {
        get const { return cast<CBasePlayer@>(self.m_hPlayer.GetEntity()); }
        set { self.m_hPlayer = EHandle(@value); }
    }
    private int GetBodygroup() {
        return 0;
    }

    private TraceResult m_trHit;
    private int m_iSwing = 0;
    
    void Spawn() {
        Precache();
        //self.m_iClip = -1;
        self.m_flCustomDmg = self.pev.dmg;
        //g_EntityFuncs.SetModel(self, self.GetW_Model("?"));
        self.m_iDefaultAmmo = 0;
        //self.pev.scale = 1.4f;

        self.FallInit();
    }
    
    void Precache() {
        self.PrecacheCustomModels();
        g_Game.PrecacheModel("models/zombie_plague/v_executioner_axe.mdl");
        g_Game.PrecacheModel("models/zombie_plague/null.mdl");
        
        g_SoundSystem.PrecacheSound("zombie_plague/weapons/executioner_axe/hit1.wav");
        g_Game.PrecacheGeneric("sound/zombie_plague/weapons/executioner_axe/hit1.wav");
        g_SoundSystem.PrecacheSound("zombie_plague/weapons/executioner_axe/hit2.wav");
        g_Game.PrecacheGeneric("sound/zombie_plague/weapons/executioner_axe/hit2.wav");
        g_SoundSystem.PrecacheSound("zombie_plague/weapons/executioner_axe/hit3.wav");
        g_Game.PrecacheGeneric("sound/zombie_plague/weapons/executioner_axe/hit3.wav");
        g_SoundSystem.PrecacheSound("zombie_plague/weapons/executioner_axe/deploy.wav");
        g_Game.PrecacheGeneric("sound/zombie_plague/weapons/executioner_axe/deploy.wav");
        g_SoundSystem.PrecacheSound("zombie_plague/weapons/executioner_axe/hitwall1.wav");
        g_Game.PrecacheGeneric("sound/zombie_plague/weapons/executioner_axe/hitwall1.wav");
        g_SoundSystem.PrecacheSound("zombie_plague/weapons/executioner_axe/stab1.wav");
        g_Game.PrecacheGeneric("sound/zombie_plague/weapons/executioner_axe/stab1.wav");
        g_SoundSystem.PrecacheSound("zombie_plague/weapons/executioner_axe/slash1.wav");
        g_Game.PrecacheGeneric("sound/zombie_plague/weapons/executioner_axe/slash1.wav");
        g_SoundSystem.PrecacheSound("zombie_plague/weapons/executioner_axe/slash2.wav");
        g_Game.PrecacheGeneric("sound/zombie_plague/weapons/executioner_axe/slash2.wav");
        
        g_Game.PrecacheGeneric("sprites/zombie_plague/cs/640hud3.spr");
        g_Game.PrecacheGeneric("sprites/zombie_plague/cs/640hud6.spr");
        g_Game.PrecacheGeneric("sprites/zombie_plague/cs/640hud7.spr");
        g_Game.PrecacheGeneric("sprites/zombie_plague/cs/640hud10.spr");
        g_Game.PrecacheGeneric("sprites/zombie_plague/cs/640hud11.spr");
        g_Game.PrecacheGeneric("sprites/zombie_plague/640hud7x.spr");
        g_Game.PrecacheGeneric("sprites/zombie_plague/640hud61.spr");
        g_Game.PrecacheGeneric("sprites/zombie_plague/weapons/weapon_executioner_axe.txt");
    }
    
    bool GetItemInfo(ItemInfo& out _Info) {
        _Info.iMaxAmmo1 = -1;
        _Info.iAmmo1Drop = WEAPON_NOCLIP;
        _Info.iMaxAmmo2 = -1;
        _Info.iAmmo2Drop = -1;
        _Info.iMaxClip = WEAPON_NOCLIP;
        _Info.iSlot = 0;
        _Info.iPosition = 10;
        _Info.iId = g_ItemRegistry.GetIdForName(self.pev.classname);
        _Info.iFlags = -1;
        _Info.iWeight = 5;

        return true;
    }

    bool AddToPlayer(CBasePlayer@ _Player) {
        if(!BaseClass.AddToPlayer(_Player))
            return false;

        NetworkMessage weapon(MSG_ONE, NetworkMessages::WeapPickup, _Player.edict());
            weapon.WriteShort(g_ItemRegistry.GetIdForName(self.pev.classname));
        weapon.End();

        return true;
    }
    
    bool Deploy() {
        self.DefaultDeploy(self.GetV_Model("models/zombie_plague/v_executioner_axe.mdl"), self.GetP_Model("models/zombie_plague/null.mdl"), kDraw, "crowbar", 0, GetBodygroup());
        self.m_flTimeWeaponIdle = self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = self.m_flNextTertiaryAttack = g_Engine.time;
        g_SoundSystem.EmitSoundDyn(m_pPlayer.edict(), CHAN_WEAPON, "zombie_plague/weapons/executioner_axe/deploy.wav", 1.0f, ATTN_NORM, 0, PITCH_NORM);
        return true;
    }

    void Holster(int _SkipLocal = 0) {
        self.m_fInReload = false;
        SetThink(null);

        m_pPlayer.pev.fuser4 = 0;

        BaseClass.Holster(_SkipLocal);
    }

    void WeaponIdle() {
        if (self.m_flTimeWeaponIdle > g_Engine.time)
            return;

        self.SendWeaponAnim(kIdle, 0, GetBodygroup());

        self.m_flTimeWeaponIdle = g_Engine.time + (150.f / 12.f);
    }
    
    bool Stab( float flDamage, string szSwingSound, string szHitFleshSound, string szHitWallSound, int& in iAnimAtkMiss, int& in iAnimAtkHit, int& in iBodygroup, 
        float flHitDist = 32.0f, float flMissNextAtk = 1.0f, float flHitNextAtk = 1.1f )
    {
        TraceResult tr;
        bool fDidHit = false;

        Math.MakeVectors( m_pPlayer.pev.v_angle );
        Vector vecSrc   = m_pPlayer.GetGunPosition();
        Vector vecEnd   = vecSrc + g_Engine.v_forward * flHitDist;

        g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );

        if( tr.flFraction >= 1.0 )
        {
            g_Utility.TraceHull( vecSrc, vecEnd, dont_ignore_monsters, head_hull, m_pPlayer.edict(), tr );
            if( tr.flFraction < 1.0 )
            {
                // Calculate the point of intersection of the line (or hull) and the object we hit
                // This is and approximation of the "best" intersection
                CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
                if( pHit is null || pHit.IsBSPModel() == true )
                    g_Utility.FindHullIntersection( vecSrc, tr, tr, VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX, m_pPlayer.edict() );

                vecEnd = tr.vecEndPos;  // This is the point on the actual surface (the hull could have hit space)
            }
        }

        if( tr.flFraction >= 1.0 ) //Missed
        {
            self.SendWeaponAnim( iAnimAtkMiss, 0, iBodygroup );

            self.m_flNextPrimaryAttack = g_Engine.time + flMissNextAtk;
            self.m_flNextSecondaryAttack = g_Engine.time + flMissNextAtk;
            self.m_flTimeWeaponIdle = g_Engine.time + 2.0f;

            // play wiff or swish sound
            g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, szSwingSound, 1, ATTN_NORM, 0, 94 + Math.RandomLong( 0,0xF ) );
            m_pPlayer.SetAnimation( PLAYER_ATTACK1 ); // player "shoot" animation
        }
        else
        {
            // hit
            fDidHit = true;
            CBaseEntity@ pEntity = g_EntityFuncs.Instance( tr.pHit );

            self.SendWeaponAnim( iAnimAtkHit, 0, iBodygroup );

            self.m_flNextPrimaryAttack = g_Engine.time + flHitNextAtk;
            self.m_flNextSecondaryAttack = g_Engine.time + flHitNextAtk;
            self.m_flTimeWeaponIdle = g_Engine.time + 2.0f;

            // player "shoot" animation
            m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

            // AdamR: Custom damage option
            if( self.m_flCustomDmg > 0 )
                flDamage = self.m_flCustomDmg;
            // AdamR: End

            if( pEntity !is null && pEntity.IsAlive() && !pEntity.IsBSPModel() && (pEntity.BloodColor() != DONT_BLEED || pEntity.Classify() != CLASS_MACHINE) )
            {
                Vector2D vec2LOS;
                float flDot;
                Vector vMyForward = g_Engine.v_forward;

                Math.MakeVectors( pEntity.pev.angles );

                vec2LOS = vMyForward.Make2D();
                vec2LOS = vec2LOS.Normalize();

                flDot = DotProduct( vec2LOS, g_Engine.v_forward.Make2D() );

                //Triple the damage if we are stabbing them in the back.
                if( flDot > 0.80f )
                {
                    flDamage *= 3.0f;
                }
            }

            g_WeaponFuncs.ClearMultiDamage();
            pEntity.TraceAttack( m_pPlayer.pev, flDamage, g_Engine.v_forward, tr, DMG_SLASH | DMG_CLUB );
            g_WeaponFuncs.ApplyMultiDamage( m_pPlayer.pev, m_pPlayer.pev );

            // play thwack, smack, or dong sound
            float flVol = 1.0;
            bool fHitWorld = true;

            if( pEntity !is null )
            {
                if( pEntity.Classify() != CLASS_NONE && pEntity.Classify() != CLASS_MACHINE && pEntity.BloodColor() != DONT_BLEED )
                {
                    if( pEntity.IsPlayer() ) // aone: lets pull them
                    {
                        pEntity.pev.velocity = pEntity.pev.velocity + (self.pev.origin - pEntity.pev.origin).Normalize() * 120;
                    } // aone: end

                    // play thwack or smack sound
                    g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, szHitFleshSound, 1, ATTN_NORM, 0, 94 + Math.RandomLong( 0,0xF ) );
                    m_pPlayer.m_iWeaponVolume = 128;

                    if( !pEntity.IsAlive() )
                        return true;
                    else
                        flVol = 0.1;

                    fHitWorld = false;
                }
            }

            // play texture hit sound
            // UNDONE: Calculate the correct point of intersection when we hit with the hull instead of the line

            if( fHitWorld )
            {
                float fvolbar = g_SoundSystem.PlayHitSound( tr, vecSrc, vecSrc + ( vecEnd - vecSrc ) * 2, BULLET_PLAYER_CROWBAR );
                //self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + 0.35; //0.25

                fvolbar = 1;

                // also play melee strike
                g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, szHitWallSound, fvolbar, ATTN_NORM, 0, 98 + Math.RandomLong( 0, 3 ) );
            }

            // delay the decal a bit
            m_trHit = tr;
            SetThink( ThinkFunction( Smack ) );
            self.pev.nextthink = g_Engine.time + 0.2;

            m_pPlayer.m_iWeaponVolume = int(flVol * 512);
        }

        return fDidHit;
    }
    
    void Smack() {
        g_WeaponFuncs.DecalGunshot(m_trHit, BULLET_PLAYER_CROWBAR);
    }
    
    bool Swing( float flDamage, string szSwingSound, string szHitFleshSound, string szHitWallSound, int& in iAnimAtk1, int& in iAnimAtk2, int& in iBodygroup, 
        float flHitDist = 48.0f, float flMissNextPriAtk = 0.35f, float flHitNextPriAtk = 0.4f, float flNextSecAtk = 0.5f )
    {
        TraceResult tr;
        bool fDidHit = false;

        Math.MakeVectors( m_pPlayer.pev.v_angle );
        Vector vecSrc   = m_pPlayer.GetGunPosition();
        Vector vecEnd   = vecSrc + g_Engine.v_forward * flHitDist;

        g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );

        if( tr.flFraction >= 1.0 )
        {
            g_Utility.TraceHull( vecSrc, vecEnd, dont_ignore_monsters, head_hull, m_pPlayer.edict(), tr );
            if( tr.flFraction < 1.0 )
            {
                // Calculate the point of intersection of the line (or hull) and the object we hit
                // This is and approximation of the "best" intersection
                CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
                if( pHit is null || pHit.IsBSPModel() == true )
                    g_Utility.FindHullIntersection( vecSrc, tr, tr, VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX, m_pPlayer.edict() );

                vecEnd = tr.vecEndPos;  // This is the point on the actual surface (the hull could have hit space)
            }
        }

        if( tr.flFraction >= 1.0 ) //Missed
        {
            switch( (m_iSwing++) % 2 )
            {
                case 0:
                {
                    self.SendWeaponAnim( iAnimAtk1, 0, iBodygroup );
                    break;
                }

                case 1:
                {
                    self.SendWeaponAnim( iAnimAtk2, 0, iBodygroup );
                    break;
                }
            }

            self.m_flNextPrimaryAttack = g_Engine.time + flMissNextPriAtk;
            self.m_flNextSecondaryAttack = g_Engine.time + flNextSecAtk;
            self.m_flTimeWeaponIdle = g_Engine.time + 2.0f;

            // play wiff or swish sound
            g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, szSwingSound, 1, ATTN_NORM, 0, 94 + Math.RandomLong( 0,0xF ) );
            m_pPlayer.SetAnimation( PLAYER_ATTACK1 ); // player "shoot" animation
        }
        else
        {
            // hit
            fDidHit = true;
            CBaseEntity@ pEntity = g_EntityFuncs.Instance( tr.pHit );

            switch( (m_iSwing++) % 2 )
            {
                case 0:
                {
                    self.SendWeaponAnim( iAnimAtk1, 0, iBodygroup );
                    break;
                }

                case 1:
                {
                    self.SendWeaponAnim( iAnimAtk2, 0, iBodygroup );
                    break;
                }
            }

            self.m_flNextPrimaryAttack = g_Engine.time + flHitNextPriAtk;
            self.m_flNextSecondaryAttack = g_Engine.time + flNextSecAtk;
            self.m_flTimeWeaponIdle = g_Engine.time + 2.0f;

            // player "shoot" animation
            m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

            // AdamR: Custom damage option
            if( self.m_flCustomDmg > 0 )
                flDamage = self.m_flCustomDmg;
            // AdamR: End

            g_WeaponFuncs.ClearMultiDamage();

            if( self.m_flNextPrimaryAttack + 0.4f < g_Engine.time )
                pEntity.TraceAttack( m_pPlayer.pev, flDamage, g_Engine.v_forward, tr, DMG_SLASH | DMG_CLUB ); // first swing does full damage
            else
                pEntity.TraceAttack( m_pPlayer.pev, flDamage * 0.75, g_Engine.v_forward, tr, DMG_SLASH | DMG_CLUB ); // subsequent swings do 75% (Changed -Sniper)

            g_WeaponFuncs.ApplyMultiDamage( m_pPlayer.pev, m_pPlayer.pev );

            // play thwack, smack, or dong sound
            float flVol = 1.0;
            bool fHitWorld = true;

            if( pEntity !is null )
            {
                if( pEntity.Classify() != CLASS_NONE && pEntity.Classify() != CLASS_MACHINE && pEntity.BloodColor() != DONT_BLEED )
                {
                    if( pEntity.IsPlayer() ) // aone: lets pull them
                    {
                        pEntity.pev.velocity = pEntity.pev.velocity + (self.pev.origin - pEntity.pev.origin).Normalize() * 120;
                    } // aone: end

                    // play thwack or smack sound
                    g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, szHitFleshSound, 1, ATTN_NORM, 0, 94 + Math.RandomLong( 0,0xF ) );
                    m_pPlayer.m_iWeaponVolume = 128;

                    if( !pEntity.IsAlive() )
                        return true;
                    else
                        flVol = 0.1;

                    fHitWorld = false;
                }
            }

            // play texture hit sound
            // UNDONE: Calculate the correct point of intersection when we hit with the hull instead of the line

            if( fHitWorld )
            {
                float fvolbar = g_SoundSystem.PlayHitSound( tr, vecSrc, vecSrc + ( vecEnd - vecSrc ) * 2, BULLET_PLAYER_CROWBAR );
                //self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + 0.35; //0.25

                fvolbar = 1;

                // also play melee strike
                g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, szHitWallSound, fvolbar, ATTN_NORM, 0, 98 + Math.RandomLong( 0, 3 ) );
            }

            // delay the decal a bit
            m_trHit = tr;
            SetThink( ThinkFunction( Smack ) );
            self.pev.nextthink = g_Engine.time + 0.2;

            m_pPlayer.m_iWeaponVolume = int(flVol * 512);
        }

        return fDidHit;
    }
    
    void PrimaryAttack() {
        Swing(250.f, (Math.RandomLong(0, 20) % 2 == 0 ? "zombie_plague/weapons/executioner_axe/slash1.wav" : "zombie_plague/weapons/executioner_axe/slash2.wav"), (Math.RandomLong(0, 75) % 3 == 0 ? "zombie_plague/weapons/executioner_axe/hit3.wav" 
            : Math.RandomLong(0, 50) % 2 == 0 ? "zombie_plague/weapons/executioner_axe/hit2.wav" : "zombie_plague/weapons/executioner_axe/hit1.wav"), "zombie_plague/weapons/executioner_axe/hitwall1.wav",
            kMidSlash1, kMidSlash2, GetBodygroup(), 64.f);
    }

    void SecondaryAttack() {
        Stab(500.f, (Math.RandomLong(0, 20) % 2 == 0 ? "zombie_plague/weapons/executioner_axe/slash1.wav" : "zombie_plague/weapons/executioner_axe/slash2.wav"), "zombie_plague/weapons/executioner_axe/stab1.wav", "zombie_plague/weapons/executioner_axe/hitwall1.wav", kStabMiss, kStab, GetBodygroup(), 64.f);
    }
}

class CLaserMine : ScriptBaseMonsterEntity {
    bool m_bHasSetHealth;
    int8 m_cMode; //Whether we are in zombie mode or human mode
    Vector m_vecTripLaserEndPos;
    float m_flBeamLength;
    float m_flLastDamageDealtTime;
    
    CLaserMine() {
        m_bHasSetHealth = false;
        m_cMode = 0;
        m_flBeamLength = -1.f;
        m_flLastDamageDealtTime = -1.f;
    }

	void Spawn() {
        BaseClass.Spawn();
		Precache();
        
		self.pev.movetype = MOVETYPE_FLY;
		self.pev.solid = SOLID_BBOX;
        
        if (!self.SetupModel())
            g_EntityFuncs.SetModel(self, "models/zombie_plague/LaserMines/v_laser_mine.mdl");
        self.pev.mins = Vector(-4.f, -4.f, -4.f);
        self.pev.maxs = Vector(4.f, 4.f, 4.f);
        self.pev.absmin = self.pev.mins;
        self.pev.absmax = self.pev.maxs;
        g_EntityFuncs.SetSize(self.pev, self.pev.mins, self.pev.maxs);
        g_EntityFuncs.DispatchObjectCollisionBox(self.edict());
        
        self.pev.gravity = 0.0f;
		self.pev.friction = 0.0f;
		self.pev.framerate = 0.0f;
        self.pev.max_health = 500.f;
        self.pev.sequence = 7 /* world */;
        self.pev.body = 3; //idk it's probably assigning world model bodyparts, just took that info from HLAM
        self.pev.takedamage = DAMAGE_YES;
        self.m_FormattedName = "Tripmine";
        self.m_bloodColor = DONT_BLEED;
        self.pev.fuser3 = -1.f;
        
        self.pev.nextthink = g_Engine.time + 0.1f;
	}
	
	void Precache() {
        g_Game.PrecacheModel("models/zombie_plague/LaserMines/v_laser_mine.mdl");
        g_Game.PrecacheModel("sprites/laserbeam.spr");
        
        g_Game.PrecacheGeneric("sound/weapons/mine_deploy.wav");
        g_SoundSystem.PrecacheSound("weapons/mine_deploy.wav");
        g_Game.PrecacheGeneric("sound/weapons/mine_charge.wav");
        g_SoundSystem.PrecacheSound("weapons/mine_charge.wav");
        g_Game.PrecacheGeneric("sound/weapons/mine_activate.wav");
        g_SoundSystem.PrecacheSound("weapons/mine_activate.wav");
        
        BaseClass.Precache();
	}
    
    int TakeDamage(entvars_t@ pevInflictor, entvars_t@ pevAttacker, float flDamage, int bitsDamageType) {
        CBaseEntity@ pEntity = g_EntityFuncs.Instance(pevInflictor);
        if (pEntity.IsPlayer()) {
            if ((bitsDamageType & DMG_CLUB) != 0 && !g_abZombies[pEntity.entindex()]) {
                if (self.pev.health < self.pev.max_health) {
                    int nEntityIdx = pEntity.entindex();
                    if (g_rgiWrenchHitCount[nEntityIdx] <= 15) {
                        self.pev.health += flDamage;
                        g_rgiWrenchHitCount[nEntityIdx] += 1;
                    }
                }
                if (self.pev.health > self.pev.max_health)
                    self.pev.health = self.pev.max_health;
                
                return 0;
            }
            if (pEntity.Classify() == CLASS_PLAYER && m_cMode == 0 /* Humans */) {
                return 0;
            }
            if (pEntity.Classify() == CLASS_TEAM2 /* red team */ && m_cMode == 1 /* zombos */) {
                return 0;
            }
        }
        
        self.pev.health -= flDamage;
        
        return 1;
    }
	
	void Think() {
        if (self.pev.health <= 0.f) {
            if (!m_bHasSetHealth) {
                if (self.pev.fuser3 != -1.f) {
                    self.pev.health = self.pev.fuser3;
                } else {
                    self.pev.health = 500.f;
                }
                m_bHasSetHealth = true;
            } else {
                SetThink(ThinkFunction(Destroy));
            }
            self.pev.nextthink = g_Engine.time + 0.1f;
            return;
        }
        
        self.pev.renderamt = 16;
        self.pev.rendermode = kRenderNormal;
        self.pev.renderfx = kRenderFxGlowShell;
        if (m_cMode == 0 /* Humans */) {
            self.pev.rendercolor = g_vecGreenColour;
        } else {
            self.pev.rendercolor = g_vecRedColour;
        }
        
        SetThink(ThinkFunction(MineActivate));
        g_SoundSystem.EmitSound(self.edict(), CHAN_VOICE, "weapons/mine_deploy.wav", 1.0f, ATTN_NORM);
        g_SoundSystem.EmitSound(self.edict(), CHAN_BODY, "weapons/mine_charge.wav", 0.2f, ATTN_NORM);
        
        self.pev.nextthink = g_Engine.time + 2.5f;
    }
    
    void MineActivate() {
        g_SoundSystem.EmitSoundDyn(self.edict(), CHAN_VOICE, "weapons/mine_activate.wav", 0.5f, ATTN_NORM, 1.0, 75);
        TraceResult tr;
        float sp = sin(ZM_UTIL_Degree2Radians(self.pev.angles.x));
        float sy = sin(ZM_UTIL_Degree2Radians(self.pev.angles.y));

        float cp = cos(ZM_UTIL_Degree2Radians(self.pev.angles.x));
        float cy = cos(ZM_UTIL_Degree2Radians(self.pev.angles.y));
                
        Vector vecEndpoint(self.pev.origin.x + 8192.f * cp * cy, self.pev.origin.y + 8192.f * cp * sy, self.pev.origin.z + 8192.f * sp);
        g_Utility.TraceLine(self.pev.origin, vecEndpoint, dont_ignore_monsters, self.edict(), tr);
        m_vecTripLaserEndPos = tr.vecEndPos;
        m_flBeamLength = tr.flFraction;
        SetThink(ThinkFunction(MineThink));
        self.pev.nextthink = g_Engine.time + 0.1f;
    }
    
    void MineThink() {
        if (self.pev.health <= 0.f) {
            SetThink(ThinkFunction(Destroy));
            self.pev.nextthink = g_Engine.time + 0.1f;
            return;
        }
        TraceResult tr;
        float sp = sin(ZM_UTIL_Degree2Radians(self.pev.angles.x));
        float sy = sin(ZM_UTIL_Degree2Radians(self.pev.angles.y));

        float cp = cos(ZM_UTIL_Degree2Radians(self.pev.angles.x));
        float cy = cos(ZM_UTIL_Degree2Radians(self.pev.angles.y));
                        
        Vector vecEndpoint(self.pev.origin.x + 8192.f * cp * cy, self.pev.origin.y + 8192.f * cp * sy, self.pev.origin.z + 8192.f * sp);
        g_Utility.TraceLine(self.pev.origin, vecEndpoint, dont_ignore_monsters, self.edict(), tr);
        if (tr.vecEndPos != m_vecTripLaserEndPos || fabsf(m_flBeamLength - tr.flFraction) > 0.001f) {
            if (tr.pHit !is null) {
                CBaseEntity@ pEntity = g_EntityFuncs.Instance(tr.pHit);
                if (tr.vecEndPos != m_vecTripLaserEndPos && pEntity.GetClassname() == "worldspawn") {
                    SetThink(ThinkFunction(Destroy));
                    self.pev.nextthink = g_Engine.time + 0.1f;
                    return;
                }
                if (pEntity !is null && pEntity.pev !is null && pEntity.GetClassname() != "worldspawn") {
                    if (pEntity.IsPlayer()) {
                        switch (m_cMode) {
                            case 0: { //Humans
                                if (g_abZombies[pEntity.entindex()]) {
                                    if (m_flLastDamageDealtTime + 1.f < g_Engine.time) {
                                        pEntity.TakeDamage(@self.pev, @self.pev.euser3.vars, 100.f, DMG_GENERIC);
                                        m_flLastDamageDealtTime = g_Engine.time;
                                    }
                                }
                            }
                                break;
                            case 1: { //Zombies
                                if (!g_abZombies[pEntity.entindex()]) {
                                    if (m_flLastDamageDealtTime + 1.f < g_Engine.time) {
                                        pEntity.TakeDamage(@self.pev, @self.pev.euser3.vars, 100.f, DMG_GENERIC);
                                        m_flLastDamageDealtTime = g_Engine.time;
                                    }
                                }
                            }
                                break;
                        }
                    }
                }
            }
        }
        
        NetworkMessage beam(MSG_PVS, NetworkMessages::SVC_TEMPENTITY, self.pev.origin);
            beam.WriteByte(TE_BEAMPOINTS); // TE id
            beam.WriteCoord(self.pev.origin.x); //x
            beam.WriteCoord(self.pev.origin.y); //y
            beam.WriteCoord(self.pev.origin.z); //z
            beam.WriteCoord(m_vecTripLaserEndPos.x); //x axis
            beam.WriteCoord(m_vecTripLaserEndPos.y); //y axis
            beam.WriteCoord(m_vecTripLaserEndPos.z); //z axis
            beam.WriteShort(g_EngineFuncs.ModelIndex("sprites/laserbeam.spr")); // sprite
            beam.WriteByte(0); // startframe
            beam.WriteByte(0); // framerate
            beam.WriteByte(2); // life
            beam.WriteByte(2); // width
            beam.WriteByte(0); // noise
            if (m_cMode == 0 /* Humans */) {
                beam.WriteByte(0); // red
                beam.WriteByte(255); // green
                beam.WriteByte(0); // blue
            } else if (m_cMode == 1 /* Zombies */) {
                beam.WriteByte(255); // red
                beam.WriteByte(0); // green
                beam.WriteByte(0); // blue
            }
            beam.WriteByte(100); // brightness
            beam.WriteByte(0); // speed
        beam.End();
        
        self.pev.nextthink = g_Engine.time + 0.03f;
    }
    
    void Destroy() {
        g_EntityFuncs.CreateExplosion(self.pev.origin, self.pev.angles, self.edict(), 20, false);
        g_EntityFuncs.Remove(self);
    }
}

array<string> g_rglpszSandbagsCreakSounds = { "debris/wood1.wav", "debris/wood2.wav", "debris/wood3.wav" };

array<int> g_rgiWrenchHitCount;

class CSandbags : ScriptBaseMonsterEntity {
    bool m_bHasSetHealth;
    
    CSandbags() {
        m_bHasSetHealth = false;
    }

	void Spawn() {
        BaseClass.Spawn();
		Precache();
        
		self.pev.movetype = MOVETYPE_FLY;
		self.pev.solid = SOLID_BBOX;
        
        if (!self.SetupModel())
            g_EntityFuncs.SetModel(self, "models/zombie_plague/sandbags.mdl");
        self.pev.mins = Vector(-27.260000f, -22.280001f, -22.290001f);
        self.pev.maxs = Vector(27.340000f,  26.629999f,  29.020000f);
        self.pev.absmin = self.pev.mins;
        self.pev.absmax = self.pev.maxs;
        g_EntityFuncs.SetSize(self.pev, self.pev.mins, self.pev.maxs);
        g_EntityFuncs.DispatchObjectCollisionBox(self.edict());
        
        self.pev.gravity = 0.0f;
		self.pev.friction = 0.0f;
		self.pev.framerate = 1.0f;
        self.pev.max_health = 2000.f;
        //self.pev.health = 2000.f;
        self.pev.takedamage = DAMAGE_YES;
        self.m_FormattedName = "Sandbags";
        self.m_bloodColor = DONT_BLEED;
        self.pev.fuser3 = -1.f;
        
        self.pev.nextthink = g_Engine.time + 0.1f;
	}
	
	void Precache() {
        g_Game.PrecacheModel("models/zombie_plague/sandbags.mdl");
        g_Game.PrecacheModel("models/woodgibs.mdl");
        
        for (uint idx = 0; idx < g_rglpszSandbagsCreakSounds.length(); idx++) {
            g_Game.PrecacheGeneric("sound/" + g_rglpszSandbagsCreakSounds[idx]);
            g_SoundSystem.PrecacheSound(g_rglpszSandbagsCreakSounds[idx]);
        }
        
        BaseClass.Precache();
	}
    
    int TakeDamage(entvars_t@ pevInflictor, entvars_t@ pevAttacker, float flDamage, int bitsDamageType) {
        CBaseEntity@ pEntity = g_EntityFuncs.Instance(pevInflictor);
        if (pEntity.IsPlayer()) {
            if ((bitsDamageType & DMG_CLUB) != 0 && !g_abZombies[pEntity.entindex()]) {
                if (self.pev.health < self.pev.max_health) {
                    int nEntityIdx = pEntity.entindex();
                    if (g_rgiWrenchHitCount[nEntityIdx] <= 15) {
                        self.pev.health += flDamage;
                        g_rgiWrenchHitCount[nEntityIdx] += 1;
                    }
                }
                if (self.pev.health > self.pev.max_health)
                    self.pev.health = self.pev.max_health;
                
                return 0;
            }
            if (pEntity.Classify() == CLASS_PLAYER) {
                return 0;
            }
        }
        
        self.pev.health -= flDamage;
        
        return 1;
    }
	
	void Think() {
        if (self.pev.health <= 0.f) {
            if (!m_bHasSetHealth) {
                if (self.pev.fuser3 != -1.f) {
                    self.pev.health = self.pev.fuser3;
                } else {
                    self.pev.health = 2000.f;
                }
                m_bHasSetHealth = true;
            } else {
                SetThink(ThinkFunction(Destroy));
            }
            self.pev.nextthink = g_Engine.time + 0.1f;
            return;
        }
        
        self.pev.renderamt = 16;
        self.pev.rendermode = kRenderNormal;
        self.pev.renderfx = kRenderFxGlowShell;
        self.pev.rendercolor = g_vecGreenColour;
        
        self.pev.nextthink = g_Engine.time + 0.5f;
    }
    
    void Destroy() {
        // Wood gibs
        NetworkMessage woodGibs(MSG_PVS, NetworkMessages::SVC_TEMPENTITY, self.pev.origin);
            woodGibs.WriteByte(TE_BREAKMODEL); // TE id
            woodGibs.WriteCoord(self.pev.origin.x); // x
            woodGibs.WriteCoord(self.pev.origin.y); // y
            woodGibs.WriteCoord(self.pev.origin.z + 24.f); // z
            woodGibs.WriteCoord(16); // size x
            woodGibs.WriteCoord(16); // size y
            woodGibs.WriteCoord(16); // size z
            woodGibs.WriteCoord(float(Math.RandomLong(-50, 50))); // velocity x
            woodGibs.WriteCoord(float(Math.RandomLong(-50, 50))); // velocity y
            woodGibs.WriteCoord(25); // velocity z
            woodGibs.WriteByte(10); // random velocity
            woodGibs.WriteShort(g_EngineFuncs.ModelIndex("models/woodgibs.mdl")); // model
            woodGibs.WriteByte(10); // count
            woodGibs.WriteByte(25); // life
            woodGibs.WriteByte(0x08 /* BREAK_WOOD */); // flags
        woodGibs.End();
        CreakSound();
        
        g_EntityFuncs.Remove(self);
    }
    
	void CreakSound() {
		g_SoundSystem.EmitSound(self.edict(), CHAN_VOICE, g_rglpszSandbagsCreakSounds[Math.RandomLong(0, g_rglpszSandbagsCreakSounds.length() - 1)], 0.90f, ATTN_NORM);
	}
}

float fabsf(float _Value) {
    if (_Value < 0.f) {
        return _Value * -1.f;
    }
    
    return _Value;
}

class CCustomGrenade : ScriptBaseEntity {
    bool m_bRegisteredSound = false;
    
    protected Vector m_vecTrailAndGlowColour;
    int m_iMode;
    protected Vector m_vecLastOrigin;
    protected Vector m_vecTripLaserEndPos;
    protected float m_flBeamLength;
    
    CCustomGrenade() {
        m_vecTrailAndGlowColour = Vector(255, 255, 255);
        m_vecLastOrigin = g_vecZero;
        m_vecTripLaserEndPos = g_vecZero;
        m_flBeamLength = 0.f;
    }
	
	void Spawn() {
		Precache();
		
		self.pev.movetype = MOVETYPE_BOUNCE;
		self.pev.solid = SOLID_BBOX;
        
        self.pev.gravity = 0.55f;
		self.pev.friction = 0.7f;
		self.pev.framerate = 1.0f;
		
		g_EntityFuncs.SetSize(self.pev, Vector(-1, -1, -1), Vector(1, 1, 1));
		
		m_bRegisteredSound = false;
	}
	
	void Precache() {
        g_Game.PrecacheModel("sprites/laserbeam.spr");
        g_Game.PrecacheModel("sprites/zombie_plague/fexplo.spr");
        g_Game.PrecacheModel("sprites/zombie_plague/zombiebomb_exp.spr");
        
        g_Game.PrecacheGeneric("sound/zombie_plague/cs/grenade/bounce.wav");
		g_SoundSystem.PrecacheSound("zombie_plague/cs/grenade/bounce.wav");
        
        g_Game.PrecacheGeneric("sound/weapons/mine_deploy.wav");
        g_SoundSystem.PrecacheSound("weapons/mine_deploy.wav");
        g_Game.PrecacheGeneric("sound/weapons/mine_charge.wav");
        g_SoundSystem.PrecacheSound("weapons/mine_charge.wav");
        g_Game.PrecacheGeneric("sound/weapons/mine_activate.wav");
        g_SoundSystem.PrecacheSound("weapons/mine_activate.wav");
	}
	
	void BounceTouch(CBaseEntity@ pOther) {
		if (pOther.edict() is self.pev.owner)
			return;
        
        if (self.pev.velocity.Length() != 0) {
            if (self.pev.owner !is null) {
                entvars_t@ pevOwner = self.pev.owner.vars;
                if (pevOwner !is null) {
                    TraceResult tr = g_Utility.GetGlobalTrace();
                    g_WeaponFuncs.ClearMultiDamage();
                    pOther.TraceAttack(pevOwner, 1, g_Engine.v_forward, tr, DMG_BLAST);
                    g_WeaponFuncs.ApplyMultiDamage(self.pev, pevOwner);
                }
            }
        }
        
        if ((self.pev.flags & FL_ONGROUND) == 0) {
            // play bounce sound
            BounceSound();
        }
        
        switch (m_iMode) {
            case 0: { //Normal
                Vector vecTestVelocity;
                
                vecTestVelocity = self.pev.velocity; 
                vecTestVelocity.z *= 0.45;
                
                if (!m_bRegisteredSound && vecTestVelocity.Length() <= 60) {
                    CBaseEntity@ pOwner = g_EntityFuncs.Instance(self.pev.owner);
                    CSoundEnt@ soundEnt = GetSoundEntInstance();
                    soundEnt.InsertSound(bits_SOUND_DANGER, self.pev.origin, int(self.pev.dmg / 0.4), 0.3, pOwner);
                    m_bRegisteredSound = true;
                }
            }
                break;
            case 1: { //Proximity
                //Does nothing in Proximity.
            }
                break;
            case 2: { //Impact
                if ((self.pev.flags & FL_ONGROUND) != 0) {
                    self.pev.velocity.x *= 0.6f;
                    self.pev.velocity.y *= 0.6f;
                    
                    self.pev.sequence = 1;
                }
                SetThink(ThinkFunction(Detonate));
                self.pev.nextthink = g_Engine.time + 0.1f;
            }
                break;
            case 3: { //Trip laser
                if (pOther.GetClassname() == "worldspawn") {
                    m_vecLastOrigin = self.pev.origin;
                    self.pev.movetype = MOVETYPE_NONE;
                    TraceResult tr;
                    float flForward = ZM_UTIL_Degree2Radians(self.pev.angles.y);
                    g_Utility.TraceLine(self.pev.origin, Vector(self.pev.origin.x + cos(flForward) * 8192.0f, self.pev.origin.y + sin(flForward) * 8192.0f, self.pev.origin.z), dont_ignore_monsters, self.edict(), tr);
                    //self.pev.angles = Math.VecToAngles(tr.vecPlaneNormal);
                    self.pev.angles = Vector(((asin(tr.vecPlaneNormal.z) * -1.f) * (180.f / g_flPI)), atan2(tr.vecPlaneNormal.y, tr.vecPlaneNormal.x) * (180.f / g_flPI), 0.f);
                    Math.MakeVectors(self.pev.angles);
                    self.pev.angles = Math.VecToAngles(g_Engine.v_forward);
                    SetThink(ThinkFunction(MineActivate));
                    self.pev.nextthink = g_Engine.time + 2.5f;
                    self.pev.solid = SOLID_NOT;
                    @self.pev.owner = null;
                    g_SoundSystem.EmitSound(self.edict(), CHAN_VOICE, "weapons/mine_deploy.wav", 1.0f, ATTN_NORM);
                    g_SoundSystem.EmitSound(self.edict(), CHAN_BODY, "weapons/mine_charge.wav", 0.2f, ATTN_NORM);
                }
            }
                break;
            case 4: { //Motion sensor
                //Does nothing in Motion sensor.
            }
                break;
            case 5: { //Satchel charge
            }
                break;
            case 6: { //Homing
            }
                break;
        }
		
		self.pev.framerate = self.pev.velocity.Length() / 200.0;
		if (self.pev.framerate > 1.0)
			self.pev.framerate = 1;
		else if (self.pev.framerate < 0.5)
			self.pev.framerate = 0;
	}
    
    void MineActivate() {
        g_SoundSystem.EmitSoundDyn(self.edict(), CHAN_VOICE, "weapons/mine_activate.wav", 0.5f, ATTN_NORM, 1.0, 75);
        TraceResult tr;
        float sp = sin(ZM_UTIL_Degree2Radians(self.pev.angles.x));
        float sy = sin(ZM_UTIL_Degree2Radians(self.pev.angles.y));

        float cp = cos(ZM_UTIL_Degree2Radians(self.pev.angles.x));
        float cy = cos(ZM_UTIL_Degree2Radians(self.pev.angles.y));
                
        Vector vecEndpoint(self.pev.origin.x + 8192.f * cp * cy, self.pev.origin.y + 8192.f * cp * sy, self.pev.origin.z + 8192.f * sp);
        g_Utility.TraceLine(self.pev.origin, vecEndpoint, dont_ignore_monsters, self.edict(), tr);
        m_vecTripLaserEndPos = tr.vecEndPos;
        m_flBeamLength = tr.flFraction;
        SetThink(ThinkFunction(TumbleThink));
        self.pev.nextthink = g_Engine.time + 0.1f;
    }
	
	void TumbleThink() {
		if (!self.IsInWorld()) {
			g_EntityFuncs.Remove(self);
			return;
		}
        
        NetworkMessage m(MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY);
            m.WriteByte(TE_BEAMFOLLOW);
            m.WriteShort(self.entindex());
            m.WriteShort(g_EngineFuncs.ModelIndex("sprites/laserbeam.spr"));
            m.WriteByte(10);
            m.WriteByte(10);
            m.WriteByte(int(m_vecTrailAndGlowColour.x)); //r
            m.WriteByte(int(m_vecTrailAndGlowColour.y)); //g
            m.WriteByte(int(m_vecTrailAndGlowColour.z)); //b
            m.WriteByte(200); //brightness
        m.End();
        
        self.pev.renderfx = kRenderFxGlowShell;
        self.pev.renderamt = 16;
        self.pev.rendercolor = m_vecTrailAndGlowColour;
        
        switch (m_iMode) {
            case 0: { //Normal
                //self.StudioFrameAdvance();
                self.pev.nextthink = g_Engine.time + 0.1f;
                
                if ((self.pev.flags & FL_ONGROUND) != 0) {
                    self.pev.velocity.x *= 0.6f;
                    self.pev.velocity.y *= 0.6f;
                
                    self.pev.sequence = 1;
                }
                
                if (self.pev.dmgtime - 1 < g_Engine.time) {
                    CBaseEntity@ pOwner = g_EntityFuncs.Instance(self.pev.owner);
                    CSoundEnt@ soundEnt = GetSoundEntInstance();
                    soundEnt.InsertSound(bits_SOUND_DANGER, self.pev.origin + self.pev.velocity * (self.pev.dmgtime - g_Engine.time), 400, 0.1, pOwner);
                }
                
                if (self.pev.dmgtime <= g_Engine.time) {
                    SetThink(ThinkFunction(Detonate));
                }
            }
                break;
            case 1: { //Proximity
                if ((self.pev.flags & FL_ONGROUND) != 0) {
                    self.pev.velocity.x *= 0.6f;
                    self.pev.velocity.y *= 0.6f;
                
                    self.pev.sequence = 1;
                }
            
                CBaseEntity@ pEntity = null;
                while ((@pEntity = g_EntityFuncs.FindEntityInSphere(pEntity, self.pev.origin, 200.f /* radius */, "player", "classname")) !is null) {
                    if (!pEntity.IsPlayer()) {
                        continue;
                    }
                    if (!pEntity.IsAlive()) {
                        continue;
                    }
                        
                    int nPlayerIdx = pEntity.entindex();
                    if (!g_abZombies[nPlayerIdx]) {
                        continue;
                    }
                    
                    SetThink(ThinkFunction(Detonate));
                    break;
                }
                        
                self.pev.nextthink = g_Engine.time + 0.1f;
            }
                break;
            case 2: { //Impact
                if ((self.pev.flags & FL_ONGROUND) != 0) {
                    self.pev.velocity.x *= 0.6f;
                    self.pev.velocity.y *= 0.6f;
                
                    self.pev.sequence = 1;
                }
                
                self.pev.nextthink = g_Engine.time + 0.1f;
            }
                break;
            case 3: { //Trip laser
                if (m_vecLastOrigin == g_vecZero) {
                    self.pev.nextthink = g_Engine.time + 0.1f; //do nothing until we are on some surface
                    return;
                }
                self.pev.velocity = g_vecZero;
                self.pev.sequence = 0;
                
                TraceResult tr;
                float sp = sin(ZM_UTIL_Degree2Radians(self.pev.angles.x));
                float sy = sin(ZM_UTIL_Degree2Radians(self.pev.angles.y));

                float cp = cos(ZM_UTIL_Degree2Radians(self.pev.angles.x));
                float cy = cos(ZM_UTIL_Degree2Radians(self.pev.angles.y));
                        
                Vector vecEndpoint(self.pev.origin.x + 8192.f * cp * cy, self.pev.origin.y + 8192.f * cp * sy, self.pev.origin.z + 8192.f * sp);
                g_Utility.TraceLine(self.pev.origin, vecEndpoint, dont_ignore_monsters, self.edict(), tr);
                if (fabsf(m_flBeamLength - tr.flFraction) > 0.001 || tr.flFraction <= 1.0f || tr.vecEndPos != m_vecTripLaserEndPos) {
                    CBaseEntity@ pEntity = g_EntityFuncs.Instance(tr.pHit);
                    if ((pEntity !is null && pEntity.pev !is null)) {
                        if (pEntity.GetClassname() != "worldspawn") {
                            if (pEntity.IsPlayer()) {
                                if (g_abZombies[pEntity.entindex()]) {
                                    SetThink(ThinkFunction(Detonate));
                                }
                            }
                        }
                    }
                    NetworkMessage beam(MSG_PVS, NetworkMessages::SVC_TEMPENTITY, self.pev.origin);
                        beam.WriteByte(TE_BEAMPOINTS); // TE id
                        beam.WriteCoord(self.pev.origin.x); //x
                        beam.WriteCoord(self.pev.origin.y); //y
                        beam.WriteCoord(self.pev.origin.z); //z
                        beam.WriteCoord(m_vecTripLaserEndPos.x); //x axis
                        beam.WriteCoord(m_vecTripLaserEndPos.y); //y axis
                        beam.WriteCoord(m_vecTripLaserEndPos.z); //z axis
                        beam.WriteShort(g_EngineFuncs.ModelIndex("sprites/laserbeam.spr")); // sprite
                        beam.WriteByte(0); // startframe
                        beam.WriteByte(0); // framerate
                        beam.WriteByte(2); // life
                        beam.WriteByte(5); // width
                        beam.WriteByte(0); // noise
                        beam.WriteByte(0); // red
                        beam.WriteByte(0); // green
                        beam.WriteByte(255); // blue
                        beam.WriteByte(200); // brightness
                        beam.WriteByte(0); // speed
                    beam.End();
                }
                
                self.pev.nextthink = g_Engine.time + 0.03f;
            }
                break;
            case 4: { //Motion sensor
                if ((self.pev.flags & FL_ONGROUND) != 0) {
                    self.pev.velocity.x *= 0.6f;
                    self.pev.velocity.y *= 0.6f;
                
                    self.pev.sequence = 1;
                }
            
                CBaseEntity@ pEntity = null;
                while ((@pEntity = g_EntityFuncs.FindEntityInSphere(pEntity, self.pev.origin, 240.f /* radius */, "player", "classname")) !is null) {
                    if (!pEntity.IsPlayer()) {
                        continue;
                    }
                    if (!pEntity.IsAlive()) {
                        continue;
                    }
                        
                    int nPlayerIdx = pEntity.entindex();
                    if (!g_abZombies[nPlayerIdx]) {
                        continue;
                    }
                    
                    if (pEntity.pev.velocity.Length() > 135.f) { //More than with +duck or +speed
                        SetThink(ThinkFunction(Detonate));
                        self.pev.nextthink = g_Engine.time + 0.1f;
                        break;
                    }
                }
                    
                self.pev.nextthink = g_Engine.time + 0.1f;
            }
                break;
            case 5: { //Satchel charge
                if ((self.pev.flags & FL_ONGROUND) != 0) {
                    self.pev.velocity.x *= 0.6f;
                    self.pev.velocity.y *= 0.6f;
                
                    self.pev.sequence = 1;
                }
                
                self.pev.nextthink = g_Engine.time + 0.1f;
            }
                break;
            case 6: { //Homing
                if ((self.pev.flags & FL_ONGROUND) != 0) {
                    self.pev.velocity.x *= 0.6f;
                    self.pev.velocity.y *= 0.6f;
                
                    self.pev.sequence = 1;
                }
                
                self.pev.nextthink = g_Engine.time + 0.1f;
            }
                break;
        }
		
		if (self.pev.waterlevel != 0) {
			self.pev.velocity = self.pev.velocity * 0.5;
			self.pev.framerate = 0.2;
            self.pev.angles = Math.VecToAngles(self.pev.velocity);
		}
	}
    
    void SatchelDetonate() {
        SetThink(ThinkFunction(Detonate));
    
        self.pev.nextthink = g_Engine.time + 0.1f;
    }
	
	void Detonate() {
        if (self.pev.flSwimTime > 0) {
            if (self.pev.flSwimTime == 1) {
                g_EntityFuncs.Remove(self);
                return;
            }
            
            NetworkMessage dlight(MSG_PAS, NetworkMessages::SVC_TEMPENTITY, self.pev.origin);
                dlight.WriteByte(TE_DLIGHT);
                dlight.WriteCoord(self.pev.origin.x);
                dlight.WriteCoord(self.pev.origin.y);
                dlight.WriteCoord(self.pev.origin.z);
                dlight.WriteByte(25); //radius
                dlight.WriteByte(255); //r
                dlight.WriteByte(255); //g
                dlight.WriteByte(255); //b
                dlight.WriteByte(21); //life
                dlight.WriteByte((self.pev.flSwimTime < 2) ? 3 : 0); //decay rate
            dlight.End();
            
            NetworkMessage sparks(MSG_PVS, NetworkMessages::SVC_TEMPENTITY, self.pev.origin);
                sparks.WriteByte(TE_SPARKS);
                sparks.WriteCoord(self.pev.origin.x);
                sparks.WriteCoord(self.pev.origin.y);
                sparks.WriteCoord(self.pev.origin.z);
            sparks.End();
            
            self.pev.flSwimTime--;
            self.pev.nextthink = g_Engine.time + 2.0f;
            
            return;
        } else if (m_iMode == 3 /* Trip laser */ && m_vecLastOrigin != g_vecZero) {
            self.pev.flSwimTime = (60 / 2); //we are ticking every two seconds
            self.pev.nextthink = g_Engine.time + 0.1f;
        } else if ((self.pev.flags & FL_ONGROUND) != 0 && self.pev.velocity.Length() < 10) {
            self.pev.flSwimTime = (60 / 2); //we are ticking every two seconds
            self.pev.nextthink = g_Engine.time + 0.1f;
            
            return;
        }
        
        if ((self.pev.flags & FL_ONGROUND) != 0) {
            self.pev.velocity.x *= 0.6f;
            self.pev.velocity.y *= 0.6f;
            
            self.pev.sequence = 1;
        }
        self.pev.nextthink = g_Engine.time + 0.1f;
	}
	
	void BounceSound() {
		g_SoundSystem.EmitSound(self.edict(), CHAN_VOICE, "zombie_plague/cs/grenade/bounce.wav", 0.50f, ATTN_NORM);
	}
}

class CCustomFireGrenade : ScriptBaseEntity {
    bool m_bRegisteredSound = false;
    
    protected Vector m_vecTrailAndGlowColour;
    int m_iMode;
    protected Vector m_vecLastOrigin;
    protected Vector m_vecTripLaserEndPos;
    protected float m_flBeamLength;
    
    CCustomFireGrenade() {
        m_vecTrailAndGlowColour = Vector(200, 0, 0);
        m_vecLastOrigin = g_vecZero;
        m_vecTripLaserEndPos = g_vecZero;
        m_flBeamLength = 0.f;
    }
	
	void Spawn() {
		Precache();
		
		self.pev.movetype = MOVETYPE_BOUNCE;
		self.pev.solid = SOLID_BBOX;
        
        self.pev.gravity = 0.55f;
		self.pev.friction = 0.7f;
		self.pev.framerate = 1.0f;
		
		g_EntityFuncs.SetSize(self.pev, Vector(-1, -1, -1), Vector(1, 1, 1));
		
		m_bRegisteredSound = false;
	}
	
	void Precache() {
        g_Game.PrecacheModel("sprites/laserbeam.spr");
        g_Game.PrecacheModel("sprites/zombie_plague/fexplo.spr");
        g_Game.PrecacheModel("sprites/zombie_plague/zombiebomb_exp.spr");
        g_Game.PrecacheModel("sprites/shockwave.spr");
        g_Game.PrecacheModel("sprites/black_smoke3.spr");
        g_Game.PrecacheModel("sprites/flame.spr");
        
        g_Game.PrecacheGeneric("sound/zombie_plague/grenade_explode.wav");
        g_SoundSystem.PrecacheSound("zombie_plague/grenade_explode.wav");
        
        g_Game.PrecacheGeneric("sound/zombie_plague/cs/grenade/bounce.wav");
		g_SoundSystem.PrecacheSound("zombie_plague/cs/grenade/bounce.wav");
        
        g_Game.PrecacheGeneric("sound/weapons/mine_deploy.wav");
        g_SoundSystem.PrecacheSound("weapons/mine_deploy.wav");
        g_Game.PrecacheGeneric("sound/weapons/mine_charge.wav");
        g_SoundSystem.PrecacheSound("weapons/mine_charge.wav");
        g_Game.PrecacheGeneric("sound/weapons/mine_activate.wav");
        g_SoundSystem.PrecacheSound("weapons/mine_activate.wav");
	}
	
	void BounceTouch(CBaseEntity@ pOther) {
		if (pOther.edict() is self.pev.owner)
			return;
        
        if (self.pev.velocity.Length() != 0) {
            if (self.pev.owner !is null) {
                entvars_t@ pevOwner = self.pev.owner.vars;
                if (pevOwner !is null) {
                    TraceResult tr = g_Utility.GetGlobalTrace();
                    g_WeaponFuncs.ClearMultiDamage();
                    pOther.TraceAttack(pevOwner, 1, g_Engine.v_forward, tr, DMG_BLAST);
                    g_WeaponFuncs.ApplyMultiDamage(self.pev, pevOwner);
                }
            }
        }
        
        if ((self.pev.flags & FL_ONGROUND) == 0) {
            // play bounce sound
            BounceSound();
        }
        
        switch (m_iMode) {
            case 0: { //Normal
                Vector vecTestVelocity;
                
                vecTestVelocity = self.pev.velocity; 
                vecTestVelocity.z *= 0.45;
                
                if (!m_bRegisteredSound && vecTestVelocity.Length() <= 60) {
                    CBaseEntity@ pOwner = g_EntityFuncs.Instance(self.pev.owner);
                    CSoundEnt@ soundEnt = GetSoundEntInstance();
                    soundEnt.InsertSound(bits_SOUND_DANGER, self.pev.origin, int(self.pev.dmg / 0.4), 0.3, pOwner);
                    m_bRegisteredSound = true;
                }
            }
                break;
            case 1: { //Proximity
                //Does nothing in Proximity.
            }
                break;
            case 2: { //Impact
                SetThink(ThinkFunction(Detonate));
                self.pev.nextthink = g_Engine.time + 0.1f;
            }
                break;
            case 3: { //Trip laser
                if (pOther.GetClassname() == "worldspawn") {
                    m_vecLastOrigin = self.pev.origin;
                    self.pev.movetype = MOVETYPE_NONE;
                    TraceResult tr;
                    float flForward = ZM_UTIL_Degree2Radians(self.pev.angles.y);
                    g_Utility.TraceLine(self.pev.origin, Vector(self.pev.origin.x + cos(flForward) * 8192.0f, self.pev.origin.y + sin(flForward) * 8192.0f, self.pev.origin.z), dont_ignore_monsters, self.edict(), tr);
                    //self.pev.angles = Math.VecToAngles(tr.vecPlaneNormal);
                    self.pev.angles = Vector(((asin(tr.vecPlaneNormal.z) * -1.f) * (180.f / g_flPI)), atan2(tr.vecPlaneNormal.y, tr.vecPlaneNormal.x) * (180.f / g_flPI), 0.f);
                    Math.MakeVectors(self.pev.angles);
                    self.pev.angles = Math.VecToAngles(g_Engine.v_forward);
                    SetThink(ThinkFunction(MineActivate));
                    self.pev.nextthink = g_Engine.time + 2.5f;
                    self.pev.solid = SOLID_NOT;
                    @self.pev.owner = null;
                    g_SoundSystem.EmitSound(self.edict(), CHAN_VOICE, "weapons/mine_deploy.wav", 1.0f, ATTN_NORM);
                    g_SoundSystem.EmitSound(self.edict(), CHAN_BODY, "weapons/mine_charge.wav", 0.2f, ATTN_NORM);
                }
            }
                break;
            case 4: { //Motion sensor
                //Does nothing in Motion sensor.
            }
                break;
            case 5: { //Satchel charge
            }
                break;
            case 6: { //Homing
            }
                break;
        }
		
		self.pev.framerate = self.pev.velocity.Length() / 200.0;
		if (self.pev.framerate > 1.0)
			self.pev.framerate = 1;
		else if (self.pev.framerate < 0.5)
			self.pev.framerate = 0;
	}
    
    void MineActivate() {
        g_SoundSystem.EmitSoundDyn(self.edict(), CHAN_VOICE, "weapons/mine_activate.wav", 0.5f, ATTN_NORM, 1.0, 75);
        TraceResult tr;
        float sp = sin(ZM_UTIL_Degree2Radians(self.pev.angles.x));
        float sy = sin(ZM_UTIL_Degree2Radians(self.pev.angles.y));

        float cp = cos(ZM_UTIL_Degree2Radians(self.pev.angles.x));
        float cy = cos(ZM_UTIL_Degree2Radians(self.pev.angles.y));
                
        Vector vecEndpoint(self.pev.origin.x + 8192.f * cp * cy, self.pev.origin.y + 8192.f * cp * sy, self.pev.origin.z + 8192.f * sp);
        g_Utility.TraceLine(self.pev.origin, vecEndpoint, dont_ignore_monsters, self.edict(), tr);
        m_vecTripLaserEndPos = tr.vecEndPos;
        m_flBeamLength = tr.flFraction;
        SetThink(ThinkFunction(TumbleThink));
        self.pev.nextthink = g_Engine.time + 0.1f;
    }
	
	void TumbleThink() {
		if (!self.IsInWorld()) {
			g_EntityFuncs.Remove(self);
			return;
		}
        
        NetworkMessage m(MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY);
            m.WriteByte(TE_BEAMFOLLOW);
            m.WriteShort(self.entindex());
            m.WriteShort(g_EngineFuncs.ModelIndex("sprites/laserbeam.spr"));
            m.WriteByte(10);
            m.WriteByte(10);
            m.WriteByte(int(m_vecTrailAndGlowColour.x)); //r
            m.WriteByte(int(m_vecTrailAndGlowColour.y)); //g
            m.WriteByte(int(m_vecTrailAndGlowColour.z)); //b
            m.WriteByte(200); //brightness
        m.End();
        
        self.pev.renderfx = kRenderFxGlowShell;
        self.pev.renderamt = 16;
        self.pev.rendercolor = m_vecTrailAndGlowColour;
        
        switch (m_iMode) {
            case 0: { //Normal
                //self.StudioFrameAdvance();
                self.pev.nextthink = g_Engine.time + 0.1f;
                
                if ((self.pev.flags & FL_ONGROUND) != 0) {
                    self.pev.velocity.x *= 0.6f;
                    self.pev.velocity.y *= 0.6f;
                
                    self.pev.sequence = 1;
                }
                
                if (self.pev.dmgtime - 1 < g_Engine.time) {
                    CBaseEntity@ pOwner = g_EntityFuncs.Instance(self.pev.owner);
                    CSoundEnt@ soundEnt = GetSoundEntInstance();
                    soundEnt.InsertSound(bits_SOUND_DANGER, self.pev.origin + self.pev.velocity * (self.pev.dmgtime - g_Engine.time), 400, 0.1, pOwner);
                }
                
                if (self.pev.dmgtime <= g_Engine.time) {
                    SetThink(ThinkFunction(Detonate));
                }
            }
                break;
            case 1: { //Proximity
                if ((self.pev.flags & FL_ONGROUND) != 0) {
                    self.pev.velocity.x *= 0.6f;
                    self.pev.velocity.y *= 0.6f;
                
                    self.pev.sequence = 1;
                }
            
                CBaseEntity@ pEntity = null;
                while ((@pEntity = g_EntityFuncs.FindEntityInSphere(pEntity, self.pev.origin, 200.f /* radius */, "player", "classname")) !is null) {
                    if (!pEntity.IsPlayer()) {
                        continue;
                    }
                    if (!pEntity.IsAlive()) {
                        continue;
                    }
                        
                    int nPlayerIdx = pEntity.entindex();
                    if (!g_abZombies[nPlayerIdx]) {
                        continue;
                    }
                    
                    SetThink(ThinkFunction(Detonate));
                    break;
                }
                        
                self.pev.nextthink = g_Engine.time + 0.1f;
            }
                break;
            case 2: { //Impact
                if ((self.pev.flags & FL_ONGROUND) != 0) {
                    self.pev.velocity.x *= 0.6f;
                    self.pev.velocity.y *= 0.6f;
                
                    self.pev.sequence = 1;
                }
                
                self.pev.nextthink = g_Engine.time + 0.1f;
            }
                break;
            case 3: { //Trip laser
                if (m_vecLastOrigin == g_vecZero) {
                    self.pev.nextthink = g_Engine.time + 0.1f; //do nothing until we are on some surface
                    return;
                }
                self.pev.velocity = g_vecZero;
                self.pev.sequence = 0;
                
                TraceResult tr;
                float sp = sin(ZM_UTIL_Degree2Radians(self.pev.angles.x));
                float sy = sin(ZM_UTIL_Degree2Radians(self.pev.angles.y));

                float cp = cos(ZM_UTIL_Degree2Radians(self.pev.angles.x));
                float cy = cos(ZM_UTIL_Degree2Radians(self.pev.angles.y));
                        
                Vector vecEndpoint(self.pev.origin.x + 8192.f * cp * cy, self.pev.origin.y + 8192.f * cp * sy, self.pev.origin.z + 8192.f * sp);
                g_Utility.TraceLine(self.pev.origin, vecEndpoint, dont_ignore_monsters, self.edict(), tr);
                if (fabsf(m_flBeamLength - tr.flFraction) > 0.001 || tr.flFraction <= 1.0f || tr.vecEndPos != m_vecTripLaserEndPos) {
                    CBaseEntity@ pEntity = g_EntityFuncs.Instance(tr.pHit);
                    if ((pEntity !is null && pEntity.pev !is null) || tr.vecEndPos != m_vecTripLaserEndPos) {
                        if (pEntity.GetClassname() != "worldspawn") {
                            if (pEntity.IsPlayer()) {
                                if (g_abZombies[pEntity.entindex()]) {
                                    SetThink(ThinkFunction(Detonate));
                                }
                            }
                        }
                    }
                    NetworkMessage beam(MSG_PVS, NetworkMessages::SVC_TEMPENTITY, self.pev.origin);
                        beam.WriteByte(TE_BEAMPOINTS); // TE id
                        beam.WriteCoord(self.pev.origin.x); //x
                        beam.WriteCoord(self.pev.origin.y); //y
                        beam.WriteCoord(self.pev.origin.z); //z
                        beam.WriteCoord(m_vecTripLaserEndPos.x); //x axis
                        beam.WriteCoord(m_vecTripLaserEndPos.y); //y axis
                        beam.WriteCoord(m_vecTripLaserEndPos.z); //z axis
                        beam.WriteShort(g_EngineFuncs.ModelIndex("sprites/laserbeam.spr")); // sprite
                        beam.WriteByte(0); // startframe
                        beam.WriteByte(0); // framerate
                        beam.WriteByte(2); // life
                        beam.WriteByte(5); // width
                        beam.WriteByte(0); // noise
                        beam.WriteByte(0); // red
                        beam.WriteByte(0); // green
                        beam.WriteByte(255); // blue
                        beam.WriteByte(200); // brightness
                        beam.WriteByte(0); // speed
                    beam.End();
                }
                
                self.pev.nextthink = g_Engine.time + 0.03f;
            }
                break;
            case 4: { //Motion sensor
                if ((self.pev.flags & FL_ONGROUND) != 0) {
                    self.pev.velocity.x *= 0.6f;
                    self.pev.velocity.y *= 0.6f;
                
                    self.pev.sequence = 1;
                }
            
                CBaseEntity@ pEntity = null;
                while ((@pEntity = g_EntityFuncs.FindEntityInSphere(pEntity, self.pev.origin, 240.f /* radius */, "player", "classname")) !is null) {
                    if (!pEntity.IsPlayer()) {
                        continue;
                    }
                    if (!pEntity.IsAlive()) {
                        continue;
                    }
                        
                    int nPlayerIdx = pEntity.entindex();
                    if (!g_abZombies[nPlayerIdx]) {
                        continue;
                    }
                    
                    if (pEntity.pev.velocity.Length() > 135.f) { //More than with +duck or +speed
                        SetThink(ThinkFunction(Detonate));
                        self.pev.nextthink = g_Engine.time + 0.1f;
                        break;
                    }
                }
                    
                self.pev.nextthink = g_Engine.time + 0.1f;
            }
                break;
            case 5: { //Satchel charge
                if ((self.pev.flags & FL_ONGROUND) != 0) {
                    self.pev.velocity.x *= 0.6f;
                    self.pev.velocity.y *= 0.6f;
                
                    self.pev.sequence = 1;
                }
                
                self.pev.nextthink = g_Engine.time + 0.1f;
            }
                break;
            case 6: { //Homing
                if ((self.pev.flags & FL_ONGROUND) != 0) {
                    self.pev.velocity.x *= 0.6f;
                    self.pev.velocity.y *= 0.6f;
                
                    self.pev.sequence = 1;
                }
                
                self.pev.nextthink = g_Engine.time + 0.1f;
            }
                break;
        }
		
		if (self.pev.waterlevel != 0) {
			self.pev.velocity = self.pev.velocity * 0.5;
			self.pev.framerate = 0.2;
            self.pev.angles = Math.VecToAngles(self.pev.velocity);
		}
	}
    
    void SatchelDetonate() {
        SetThink(ThinkFunction(Detonate));
    
        self.pev.nextthink = g_Engine.time + 0.1f;
    }
    
    void CreateExplosionRing(const Vector& in _Origin) {
        // Smallest ring
        NetworkMessage smallest_ring(MSG_PVS, NetworkMessages::SVC_TEMPENTITY, _Origin);
            smallest_ring.WriteByte(TE_BEAMCYLINDER); // TE id
            smallest_ring.WriteCoord(_Origin.x); //x
            smallest_ring.WriteCoord(_Origin.y); //y
            smallest_ring.WriteCoord(_Origin.z); //z
            smallest_ring.WriteCoord(_Origin.x); //x axis
            smallest_ring.WriteCoord(_Origin.y); //y axis
            smallest_ring.WriteCoord(_Origin.z + 385.f); //z axis
            smallest_ring.WriteShort(g_EngineFuncs.ModelIndex("sprites/shockwave.spr")); // sprite
            smallest_ring.WriteByte(0); // startframe
            smallest_ring.WriteByte(0); // framerate
            smallest_ring.WriteByte(4); // life
            smallest_ring.WriteByte(60); // width
            smallest_ring.WriteByte(0); // noise
            smallest_ring.WriteByte(200); // red
            smallest_ring.WriteByte(100); // green
            smallest_ring.WriteByte(0); // blue
            smallest_ring.WriteByte(200); // brightness
            smallest_ring.WriteByte(0); // speed
        smallest_ring.End();
        
        // Medium ring
        NetworkMessage medium_ring(MSG_PVS, NetworkMessages::SVC_TEMPENTITY, _Origin);
            medium_ring.WriteByte(TE_BEAMCYLINDER); // TE id
            medium_ring.WriteCoord(_Origin.x); //x
            medium_ring.WriteCoord(_Origin.y); //y
            medium_ring.WriteCoord(_Origin.z); //z
            medium_ring.WriteCoord(_Origin.x); //x axis
            medium_ring.WriteCoord(_Origin.y); //y axis
            medium_ring.WriteCoord(_Origin.z + 470.f); //z axis
            medium_ring.WriteShort(g_EngineFuncs.ModelIndex("sprites/shockwave.spr")); // sprite
            medium_ring.WriteByte(0); // startframe
            medium_ring.WriteByte(0); // framerate
            medium_ring.WriteByte(4); // life
            medium_ring.WriteByte(60); // width
            medium_ring.WriteByte(0); // noise
            medium_ring.WriteByte(200); // red
            medium_ring.WriteByte(50); // green
            medium_ring.WriteByte(0); // blue
            medium_ring.WriteByte(200); // brightness
            medium_ring.WriteByte(0); // speed
        medium_ring.End();
        
        // Largest ring
        NetworkMessage largest_ring(MSG_PVS, NetworkMessages::SVC_TEMPENTITY, _Origin);
            largest_ring.WriteByte(TE_BEAMCYLINDER); // TE id
            largest_ring.WriteCoord(_Origin.x); //x
            largest_ring.WriteCoord(_Origin.y); //y
            largest_ring.WriteCoord(_Origin.z); //z
            largest_ring.WriteCoord(_Origin.x); //x axis
            largest_ring.WriteCoord(_Origin.y); //y axis
            largest_ring.WriteCoord(_Origin.z + 555.f); //z axis
            largest_ring.WriteShort(g_EngineFuncs.ModelIndex("sprites/shockwave.spr")); // sprite
            largest_ring.WriteByte(0); // startframe
            largest_ring.WriteByte(0); // framerate
            largest_ring.WriteByte(4); // life
            largest_ring.WriteByte(60); // width
            largest_ring.WriteByte(0); // noise
            largest_ring.WriteByte(200); // red
            largest_ring.WriteByte(0); // green
            largest_ring.WriteByte(0); // blue
            largest_ring.WriteByte(200); // brightness
            largest_ring.WriteByte(0); // speed
        largest_ring.End();
    }
	
	void Detonate() {
        CreateExplosionRing(self.pev.origin);
        
        g_SoundSystem.EmitSound(self.edict(), CHAN_WEAPON, "zombie_plague/grenade_explode.wav", 1.0f, ATTN_NORM);
        
        CBaseEntity@ pEntity = null;
        while ((@pEntity = g_EntityFuncs.FindEntityInSphere(pEntity, self.pev.origin, 240.f /* radius */, "player", "classname")) !is null) {
            if (!pEntity.IsPlayer()) {
                //g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[ZP] [DEBUG] Not a player: " + string(pEntity.pev.classname) + "\n");
                continue;
            }
            if (!pEntity.IsAlive()) {
                //g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[ZP] [DEBUG] Not alive: " + string(pEntity.pev.netname) + "\n");
                continue;
            }
                
            int nPlayerIdx = pEntity.entindex();
            if (!g_abZombies[nPlayerIdx]) {
                //g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[ZP] [DEBUG] Not zombie: " + string(pEntity.pev.netname) + "\n");
                continue;
            }
            
			g_aiZombieBurnDuration[nPlayerIdx] += 50;
            if (g_rglpfnBurningLoops[nPlayerIdx] !is null && !g_rglpfnBurningLoops[nPlayerIdx].HasBeenRemoved())
                g_Scheduler.RemoveTimer(g_rglpfnBurningLoops[nPlayerIdx]);
            @g_rglpfnBurningLoops[nPlayerIdx] = g_Scheduler.SetTimeout("ZM_FireGrenade_BurnAZombie", 0.2f, EHandle(pEntity));
        }
        
        g_EntityFuncs.Remove(self);
	}
	
	void BounceSound() {
		g_SoundSystem.EmitSound(self.edict(), CHAN_VOICE, "zombie_plague/cs/grenade/bounce.wav", 0.50f, ATTN_NORM);
	}
}

void ZM_FireGrenade_BurnAZombie(EHandle _Zombie) {
    if (!_Zombie.IsValid())
        return;
        
    CBaseEntity@ pEntity = _Zombie.GetEntity(); 
    if (!pEntity.IsAlive())
        return;
    CBasePlayer@ pPlayer = cast<CBasePlayer@>(pEntity);
    Observer@ pObserver = pPlayer.GetObserver();
    if (pObserver.IsObserver())
        return;
    
    int nEntityIdx = pEntity.entindex();
    
    //Reserved for future: Antidot. ~ xWhitey
    if (!g_abZombies[nEntityIdx]) {
        return;
    }
    
    if ((pEntity.pev.flags & FL_INWATER) != 0 || g_aiZombieBurnDuration[nEntityIdx] < 1) {
        // Smoke sprite
        NetworkMessage smoke(MSG_PVS, NetworkMessages::SVC_TEMPENTITY, pEntity.pev.origin);
            smoke.WriteByte(TE_SMOKE); // TE id
            smoke.WriteCoord(pEntity.pev.origin.x); // x
            smoke.WriteCoord(pEntity.pev.origin.y); // y
            smoke.WriteCoord(pEntity.pev.origin.z - 50.f); // z
            smoke.WriteShort(g_EngineFuncs.ModelIndex("sprites/black_smoke3.spr")); // sprite
            smoke.WriteByte(Math.RandomLong(15, 20)); // scale
            smoke.WriteByte(Math.RandomLong(10, 20)); // framerate
		smoke.End();
		
		return;
    }
    
    if (Math.RandomLong(1, 20) == 1) {
        if (g_abIsNemesis[nEntityIdx]) {
            ZM_UTIL_PlayRandomNemesisPainSound(pEntity.edict());
        } else {
            ZM_UTIL_PlayRandomBurnSound(pEntity.edict());
        }
    }
    
    pEntity.pev.velocity.x *= 0.35f;
    pEntity.pev.velocity.y *= 0.35f;
    
    if ((pEntity.pev.health - 5.f) > 0.f) {
        pEntity.pev.health = pEntity.pev.health - 5.f;
    }
    
    // Flame sprite
	NetworkMessage flame(MSG_PVS, NetworkMessages::SVC_TEMPENTITY, pEntity.pev.origin);
        flame.WriteByte(TE_SPRITE); // TE id
        flame.WriteCoord(pEntity.pev.origin.x + float(Math.RandomLong(-5, 5))); // x
        flame.WriteCoord(pEntity.pev.origin.y + float(Math.RandomLong(-5, 5))); // y
        flame.WriteCoord(pEntity.pev.origin.z + float(Math.RandomLong(-10, 10))); // z
        flame.WriteShort(g_EngineFuncs.ModelIndex("sprites/flame.spr")); // sprite
        flame.WriteByte(Math.RandomLong(5, 10)); // scale
        flame.WriteByte(200); // brightness
	flame.End();
    
    g_aiZombieBurnDuration[nEntityIdx]--;
    
    @g_rglpfnBurningLoops[nEntityIdx] = g_Scheduler.SetTimeout("ZM_FireGrenade_BurnAZombie", 0.2f, EHandle(pEntity));
}

class CCustomFrostGrenade : ScriptBaseEntity {
    bool m_bRegisteredSound = false;
    
    protected Vector m_vecTrailAndGlowColour;
    int m_iMode;
    protected Vector m_vecLastOrigin;    
    protected Vector m_vecTripLaserEndPos;
    protected float m_flBeamLength;
    
    CCustomFrostGrenade() {
        m_vecTrailAndGlowColour = Vector(0, 100, 200);
        m_vecLastOrigin = g_vecZero;
        m_vecTripLaserEndPos = g_vecZero;
        m_flBeamLength = 0.f;
    }
	
	void Spawn() {
		Precache();
		
		self.pev.movetype = MOVETYPE_BOUNCE;
		self.pev.solid = SOLID_BBOX;
        
        self.pev.gravity = 0.55f;
		self.pev.friction = 0.7f;
		self.pev.framerate = 1.0f;
		
		g_EntityFuncs.SetSize(self.pev, Vector(-1, -1, -1), Vector(1, 1, 1));
		
		m_bRegisteredSound = false;
	}
	
	void Precache() {
        g_Game.PrecacheModel("sprites/laserbeam.spr");
        g_Game.PrecacheModel("sprites/zombie_plague/fexplo.spr");
        g_Game.PrecacheModel("sprites/zombie_plague/zombiebomb_exp.spr");
        g_Game.PrecacheModel("sprites/shockwave.spr");
        g_Game.PrecacheModel("models/glassgibs.mdl");
        
        //Grenade explode
        g_Game.PrecacheGeneric("sound/zombie_plague/warcraft3/frostnova.wav");
		g_SoundSystem.PrecacheSound("zombie_plague/warcraft3/frostnova.wav");
        //Player frozen
        g_Game.PrecacheGeneric("sound/zombie_plague/warcraft3/impalehit.wav");
		g_SoundSystem.PrecacheSound("zombie_plague/warcraft3/impalehit.wav");
        //Freeze cleared
        g_Game.PrecacheGeneric("sound/zombie_plague/warcraft3/impalelaunch1.wav");
		g_SoundSystem.PrecacheSound("zombie_plague/warcraft3/impalelaunch1.wav");
        
        g_Game.PrecacheGeneric("sound/zombie_plague/cs/grenade/bounce.wav");
		g_SoundSystem.PrecacheSound("zombie_plague/cs/grenade/bounce.wav");
        
        g_Game.PrecacheGeneric("sound/weapons/mine_deploy.wav");
        g_SoundSystem.PrecacheSound("weapons/mine_deploy.wav");
        g_Game.PrecacheGeneric("sound/weapons/mine_charge.wav");
        g_SoundSystem.PrecacheSound("weapons/mine_charge.wav");
        g_Game.PrecacheGeneric("sound/weapons/mine_activate.wav");
        g_SoundSystem.PrecacheSound("weapons/mine_activate.wav");
	}
	
	void BounceTouch(CBaseEntity@ pOther) {
		if (pOther.edict() is self.pev.owner)
			return;
        
        if (self.pev.velocity.Length() != 0) {
            if (self.pev.owner !is null) {
                entvars_t@ pevOwner = self.pev.owner.vars;
                if (pevOwner !is null) {
                    TraceResult tr = g_Utility.GetGlobalTrace();
                    g_WeaponFuncs.ClearMultiDamage();
                    pOther.TraceAttack(pevOwner, 1, g_Engine.v_forward, tr, DMG_BLAST);
                    g_WeaponFuncs.ApplyMultiDamage(self.pev, pevOwner);
                }
            }
        }
        
        if ((self.pev.flags & FL_ONGROUND) == 0) {
            // play bounce sound
            BounceSound();
        }
        
        switch (m_iMode) {
            case 0: { //Normal
                Vector vecTestVelocity;
                
                vecTestVelocity = self.pev.velocity; 
                vecTestVelocity.z *= 0.45;
                
                if (!m_bRegisteredSound && vecTestVelocity.Length() <= 60) {
                    CBaseEntity@ pOwner = g_EntityFuncs.Instance(self.pev.owner);
                    CSoundEnt@ soundEnt = GetSoundEntInstance();
                    soundEnt.InsertSound(bits_SOUND_DANGER, self.pev.origin, int(self.pev.dmg / 0.4), 0.3, pOwner);
                    m_bRegisteredSound = true;
                }
            }
                break;
            case 1: { //Proximity
                //Does nothing in Proximity.
            }
                break;
            case 2: { //Impact
                SetThink(ThinkFunction(Detonate));
                self.pev.nextthink = g_Engine.time + 0.1f;
            }
                break;
            case 3: { //Trip laser
                if (pOther.GetClassname() == "worldspawn") {
                    m_vecLastOrigin = self.pev.origin;
                    self.pev.movetype = MOVETYPE_NONE;
                    TraceResult tr;
                    float flForward = ZM_UTIL_Degree2Radians(self.pev.angles.y);
                    g_Utility.TraceLine(self.pev.origin, Vector(self.pev.origin.x + cos(flForward) * 8192.0f, self.pev.origin.y + sin(flForward) * 8192.0f, self.pev.origin.z), dont_ignore_monsters, self.edict(), tr);
                    //self.pev.angles = Math.VecToAngles(tr.vecPlaneNormal);
                    self.pev.angles = Vector(((asin(tr.vecPlaneNormal.z) * -1.f) * (180.f / g_flPI)), atan2(tr.vecPlaneNormal.y, tr.vecPlaneNormal.x) * (180.f / g_flPI), 0.f);
                    Math.MakeVectors(self.pev.angles);
                    self.pev.angles = Math.VecToAngles(g_Engine.v_forward);
                    SetThink(ThinkFunction(MineActivate));
                    self.pev.nextthink = g_Engine.time + 2.5f;
                    self.pev.solid = SOLID_NOT;
                    @self.pev.owner = null;
                    g_SoundSystem.EmitSound(self.edict(), CHAN_VOICE, "weapons/mine_deploy.wav", 1.0f, ATTN_NORM);
                    g_SoundSystem.EmitSound(self.edict(), CHAN_BODY, "weapons/mine_charge.wav", 0.2f, ATTN_NORM);
                }
            }
                break;
            case 4: { //Motion sensor
                //Does nothing in Motion sensor.
            }
                break;
            case 5: { //Satchel charge
            }
                break;
            case 6: { //Homing
            }
                break;
        }
		
		self.pev.framerate = self.pev.velocity.Length() / 200.0;
		if (self.pev.framerate > 1.0)
			self.pev.framerate = 1;
		else if (self.pev.framerate < 0.5)
			self.pev.framerate = 0;
	}
    
    void MineActivate() {
        g_SoundSystem.EmitSoundDyn(self.edict(), CHAN_VOICE, "weapons/mine_activate.wav", 0.5f, ATTN_NORM, 1.0, 75);
        TraceResult tr;
        float sp = sin(ZM_UTIL_Degree2Radians(self.pev.angles.x));
        float sy = sin(ZM_UTIL_Degree2Radians(self.pev.angles.y));

        float cp = cos(ZM_UTIL_Degree2Radians(self.pev.angles.x));
        float cy = cos(ZM_UTIL_Degree2Radians(self.pev.angles.y));
                
        Vector vecEndpoint(self.pev.origin.x + 8192.f * cp * cy, self.pev.origin.y + 8192.f * cp * sy, self.pev.origin.z + 8192.f * sp);
        g_Utility.TraceLine(self.pev.origin, vecEndpoint, dont_ignore_monsters, self.edict(), tr);
        m_vecTripLaserEndPos = tr.vecEndPos;
        m_flBeamLength = tr.flFraction;
        SetThink(ThinkFunction(TumbleThink));
        self.pev.nextthink = g_Engine.time + 0.1f;
    }
	
	void TumbleThink() {
		if (!self.IsInWorld()) {
			g_EntityFuncs.Remove(self);
			return;
		}
        
        NetworkMessage m(MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY);
            m.WriteByte(TE_BEAMFOLLOW);
            m.WriteShort(self.entindex());
            m.WriteShort(g_EngineFuncs.ModelIndex("sprites/laserbeam.spr"));
            m.WriteByte(10);
            m.WriteByte(10);
            m.WriteByte(int(m_vecTrailAndGlowColour.x)); //r
            m.WriteByte(int(m_vecTrailAndGlowColour.y)); //g
            m.WriteByte(int(m_vecTrailAndGlowColour.z)); //b
            m.WriteByte(200); //brightness
        m.End();
        
        self.pev.renderfx = kRenderFxGlowShell;
        self.pev.renderamt = 16;
        self.pev.rendercolor = m_vecTrailAndGlowColour;
		
        switch (m_iMode) {
            case 0: { //Normal
                //self.StudioFrameAdvance();
                self.pev.nextthink = g_Engine.time + 0.1f;
                
                if ((self.pev.flags & FL_ONGROUND) != 0) {
                    self.pev.velocity.x *= 0.6f;
                    self.pev.velocity.y *= 0.6f;
                
                    self.pev.sequence = 1;
                }
                
                if (self.pev.dmgtime - 1 < g_Engine.time) {
                    CBaseEntity@ pOwner = g_EntityFuncs.Instance(self.pev.owner);
                    CSoundEnt@ soundEnt = GetSoundEntInstance();
                    soundEnt.InsertSound(bits_SOUND_DANGER, self.pev.origin + self.pev.velocity * (self.pev.dmgtime - g_Engine.time), 400, 0.1, pOwner);
                }
                
                if (self.pev.dmgtime <= g_Engine.time) {
                    SetThink(ThinkFunction(Detonate));
                }
            }
                break;
            case 1: { //Proximity
                if ((self.pev.flags & FL_ONGROUND) != 0) {
                    self.pev.velocity.x *= 0.6f;
                    self.pev.velocity.y *= 0.6f;
                
                    self.pev.sequence = 1;
                }
            
                CBaseEntity@ pEntity = null;
                while ((@pEntity = g_EntityFuncs.FindEntityInSphere(pEntity, self.pev.origin, 200.f /* radius */, "player", "classname")) !is null) {
                    if (!pEntity.IsPlayer()) {
                        continue;
                    }
                    if (!pEntity.IsAlive()) {
                        continue;
                    }
                        
                    int nPlayerIdx = pEntity.entindex();
                    if (!g_abZombies[nPlayerIdx]) {
                        continue;
                    }
                    
                    SetThink(ThinkFunction(Detonate));
                    break;
                }
                
                self.pev.nextthink = g_Engine.time + 0.1f;
            }
                break;
            case 2: { //Impact
                if ((self.pev.flags & FL_ONGROUND) != 0) {
                    self.pev.velocity.x *= 0.6f;
                    self.pev.velocity.y *= 0.6f;
                
                    self.pev.sequence = 1;
                }
                
                self.pev.nextthink = g_Engine.time + 0.1f;
            }
                break;
            case 3: { //Trip laser
                if (m_vecLastOrigin == g_vecZero) {
                    self.pev.nextthink = g_Engine.time + 0.1f; //do nothing until we are on some surface
                    return;
                }
                self.pev.velocity = g_vecZero;
                self.pev.sequence = 0;
                
                TraceResult tr;
                float sp = sin(ZM_UTIL_Degree2Radians(self.pev.angles.x));
                float sy = sin(ZM_UTIL_Degree2Radians(self.pev.angles.y));

                float cp = cos(ZM_UTIL_Degree2Radians(self.pev.angles.x));
                float cy = cos(ZM_UTIL_Degree2Radians(self.pev.angles.y));
                        
                Vector vecEndpoint(self.pev.origin.x + 8192.f * cp * cy, self.pev.origin.y + 8192.f * cp * sy, self.pev.origin.z + 8192.f * sp);
                g_Utility.TraceLine(self.pev.origin, vecEndpoint, dont_ignore_monsters, self.edict(), tr);
                if (fabsf(m_flBeamLength - tr.flFraction) > 0.001 || tr.flFraction <= 1.0f || tr.vecEndPos != m_vecTripLaserEndPos) {
                    CBaseEntity@ pEntity = g_EntityFuncs.Instance(tr.pHit);
                    if ((pEntity !is null && pEntity.pev !is null) || tr.vecEndPos != m_vecTripLaserEndPos) {
                        if (pEntity.GetClassname() != "worldspawn") {
                            if (pEntity.IsPlayer()) {
                                if (g_abZombies[pEntity.entindex()]) {
                                    SetThink(ThinkFunction(Detonate));
                                }
                            }
                        }
                    }
                    NetworkMessage beam(MSG_PVS, NetworkMessages::SVC_TEMPENTITY, self.pev.origin);
                        beam.WriteByte(TE_BEAMPOINTS); // TE id
                        beam.WriteCoord(self.pev.origin.x); //x
                        beam.WriteCoord(self.pev.origin.y); //y
                        beam.WriteCoord(self.pev.origin.z); //z
                        beam.WriteCoord(m_vecTripLaserEndPos.x); //x axis
                        beam.WriteCoord(m_vecTripLaserEndPos.y); //y axis
                        beam.WriteCoord(m_vecTripLaserEndPos.z); //z axis
                        beam.WriteShort(g_EngineFuncs.ModelIndex("sprites/laserbeam.spr")); // sprite
                        beam.WriteByte(0); // startframe
                        beam.WriteByte(0); // framerate
                        beam.WriteByte(2); // life
                        beam.WriteByte(5); // width
                        beam.WriteByte(0); // noise
                        beam.WriteByte(0); // red
                        beam.WriteByte(0); // green
                        beam.WriteByte(255); // blue
                        beam.WriteByte(200); // brightness
                        beam.WriteByte(0); // speed
                    beam.End();
                }
                
                self.pev.nextthink = g_Engine.time + 0.03f;
            }
                break;
            case 4: { //Motion sensor
                if ((self.pev.flags & FL_ONGROUND) != 0) {
                    self.pev.velocity.x *= 0.6f;
                    self.pev.velocity.y *= 0.6f;
                
                    self.pev.sequence = 1;
                }
            
                CBaseEntity@ pEntity = null;
                while ((@pEntity = g_EntityFuncs.FindEntityInSphere(pEntity, self.pev.origin, 240.f /* radius */, "player", "classname")) !is null) {
                    if (!pEntity.IsPlayer()) {
                        continue;
                    }
                    if (!pEntity.IsAlive()) {
                        continue;
                    }
                        
                    int nPlayerIdx = pEntity.entindex();
                    if (!g_abZombies[nPlayerIdx]) {
                        continue;
                    }
                    
                    if (pEntity.pev.velocity.Length() > 135.f) { //More than with +duck or +speed
                        SetThink(ThinkFunction(Detonate));
                        self.pev.nextthink = g_Engine.time + 0.1f;
                        break;
                    }
                }
                    
                self.pev.nextthink = g_Engine.time + 0.1f;
            }
                break;
            case 5: { //Satchel charge
                if ((self.pev.flags & FL_ONGROUND) != 0) {
                    self.pev.velocity.x *= 0.6f;
                    self.pev.velocity.y *= 0.6f;
                
                    self.pev.sequence = 1;
                }
                
                self.pev.nextthink = g_Engine.time + 0.1f;
            }
                break;
            case 6: { //Homing
                if ((self.pev.flags & FL_ONGROUND) != 0) {
                    self.pev.velocity.x *= 0.6f;
                    self.pev.velocity.y *= 0.6f;
                
                    self.pev.sequence = 1;
                }
                
                self.pev.nextthink = g_Engine.time + 0.1f;
            }
                break;
        }
        
		if (self.pev.waterlevel != 0) {
			self.pev.velocity = self.pev.velocity * 0.5;
			self.pev.framerate = 0.2;
            self.pev.angles = Math.VecToAngles(self.pev.velocity);
		}
	}
    
    void CreateExplosionRing(const Vector& in _Origin) {
        // Smallest ring
        NetworkMessage smallest_ring(MSG_PVS, NetworkMessages::SVC_TEMPENTITY, _Origin);
            smallest_ring.WriteByte(TE_BEAMCYLINDER); // TE id
            smallest_ring.WriteCoord(_Origin.x); //x
            smallest_ring.WriteCoord(_Origin.y); //y
            smallest_ring.WriteCoord(_Origin.z); //z
            smallest_ring.WriteCoord(_Origin.x); //x axis
            smallest_ring.WriteCoord(_Origin.y); //y axis
            smallest_ring.WriteCoord(_Origin.z + 385.f); //z axis
            smallest_ring.WriteShort(g_EngineFuncs.ModelIndex("sprites/shockwave.spr")); // sprite
            smallest_ring.WriteByte(0); // startframe
            smallest_ring.WriteByte(0); // framerate
            smallest_ring.WriteByte(4); // life
            smallest_ring.WriteByte(60); // width
            smallest_ring.WriteByte(0); // noise
            smallest_ring.WriteByte(0); // red
            smallest_ring.WriteByte(100); // green
            smallest_ring.WriteByte(200); // blue
            smallest_ring.WriteByte(200); // brightness
            smallest_ring.WriteByte(0); // speed
        smallest_ring.End();
        
        // Medium ring
        NetworkMessage medium_ring(MSG_PVS, NetworkMessages::SVC_TEMPENTITY, _Origin);
            medium_ring.WriteByte(TE_BEAMCYLINDER); // TE id
            medium_ring.WriteCoord(_Origin.x); //x
            medium_ring.WriteCoord(_Origin.y); //y
            medium_ring.WriteCoord(_Origin.z); //z
            medium_ring.WriteCoord(_Origin.x); //x axis
            medium_ring.WriteCoord(_Origin.y); //y axis
            medium_ring.WriteCoord(_Origin.z + 470.f); //z axis
            medium_ring.WriteShort(g_EngineFuncs.ModelIndex("sprites/shockwave.spr")); // sprite
            medium_ring.WriteByte(0); // startframe
            medium_ring.WriteByte(0); // framerate
            medium_ring.WriteByte(4); // life
            medium_ring.WriteByte(60); // width
            medium_ring.WriteByte(0); // noise
            medium_ring.WriteByte(0); // red
            medium_ring.WriteByte(100); // green
            medium_ring.WriteByte(200); // blue
            medium_ring.WriteByte(200); // brightness
            medium_ring.WriteByte(0); // speed
        medium_ring.End();
        
        // Largest ring
        NetworkMessage largest_ring(MSG_PVS, NetworkMessages::SVC_TEMPENTITY, _Origin);
            largest_ring.WriteByte(TE_BEAMCYLINDER); // TE id
            largest_ring.WriteCoord(_Origin.x); //x
            largest_ring.WriteCoord(_Origin.y); //y
            largest_ring.WriteCoord(_Origin.z); //z
            largest_ring.WriteCoord(_Origin.x); //x axis
            largest_ring.WriteCoord(_Origin.y); //y axis
            largest_ring.WriteCoord(_Origin.z + 555.f); //z axis
            largest_ring.WriteShort(g_EngineFuncs.ModelIndex("sprites/shockwave.spr")); // sprite
            largest_ring.WriteByte(0); // startframe
            largest_ring.WriteByte(0); // framerate
            largest_ring.WriteByte(4); // life
            largest_ring.WriteByte(60); // width
            largest_ring.WriteByte(0); // noise
            largest_ring.WriteByte(0); // red
            largest_ring.WriteByte(100); // green
            largest_ring.WriteByte(200); // blue
            largest_ring.WriteByte(200); // brightness
            largest_ring.WriteByte(0); // speed
        largest_ring.End();
    }
    
    void SatchelDetonate() {
        SetThink(ThinkFunction(Detonate));
    
        self.pev.nextthink = g_Engine.time + 0.1f;
    }
	
	void Detonate() {
        CreateExplosionRing(self.pev.origin);
        
        g_SoundSystem.EmitSound(self.edict(), CHAN_WEAPON, "zombie_plague/warcraft3/frostnova.wav", 1.0f, ATTN_NORM);
        
        CBaseEntity@ pEntity = null;
        while ((@pEntity = g_EntityFuncs.FindEntityInSphere(pEntity, self.pev.origin, 240.f /* radius */, "player", "classname")) !is null) {
            if (!pEntity.IsPlayer()) {
                //g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[ZP] [DEBUG] Not a player: " + string(pEntity.pev.classname) + "\n");
                continue;
            }
            if (!pEntity.IsAlive()) {
                //g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[ZP] [DEBUG] Not alive: " + string(pEntity.pev.netname) + "\n");
                continue;
            }
                
            int nPlayerIdx = pEntity.entindex();
            if (!g_abZombies[nPlayerIdx]) {
                //g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[ZP] [DEBUG] Not zombie: " + string(pEntity.pev.netname) + "\n");
                continue;
            }
            if (g_abIsZombieFrozen[nPlayerIdx]) {
                continue;
            }
            
            g_SoundSystem.EmitSound(pEntity.edict(), CHAN_BODY, "zombie_plague/warcraft3/impalehit.wav", 1.0f, ATTN_NORM);
            
            CBackupFrostNadePlayerData@ pBackupData = CBackupFrostNadePlayerData();
            pBackupData.m_iRenderMode = pEntity.pev.rendermode;
            pBackupData.m_flRenderAmount = pEntity.pev.renderamt;
            pBackupData.m_vecRenderColor = pEntity.pev.rendercolor;
            pBackupData.m_iRenderFX = pEntity.pev.renderfx;
            pBackupData.m_vecOriginalVelocity = pEntity.pev.velocity;
            pBackupData.m_vecOriginalOrigin = pEntity.pev.origin;
            @g_rglpBackupFrostNadePlayerData[nPlayerIdx] = @pBackupData;
            
            pEntity.pev.renderfx = kRenderFxGlowShell;
            pEntity.pev.rendercolor = Vector(0, 100, 200);
            pEntity.pev.rendermode = kRenderNormal;
            pEntity.pev.renderamt = 25.f;
            pEntity.pev.velocity = g_vecZero;
            
			g_abIsZombieFrozen[nPlayerIdx] = true;
            if (g_rglpfnFrozenLoops[nPlayerIdx] !is null && !g_rglpfnFrozenLoops[nPlayerIdx].HasBeenRemoved())
                g_Scheduler.RemoveTimer(g_rglpfnFrozenLoops[nPlayerIdx]);
            @g_rglpfnFrozenLoops[nPlayerIdx] = g_Scheduler.SetTimeout("ZM_FrostGrenade_KeepFrozen", 0.0f, EHandle(pEntity));
            @g_rglpfnUnfreezeScheds[nPlayerIdx] = g_Scheduler.SetTimeout("ZM_FrostGrenade_UnfreezeZombie", 3.5f, EHandle(pEntity));
        }
        
        g_EntityFuncs.Remove(self);
	}
	
	void BounceSound() {
		g_SoundSystem.EmitSound(self.edict(), CHAN_VOICE, "zombie_plague/cs/grenade/bounce.wav", 0.50f, ATTN_NORM);
	}
}

void ZM_FrostGrenade_KeepFrozen(EHandle _Zombie) {
    if (!_Zombie.IsValid())
        return;
        
    CBaseEntity@ pEntity = _Zombie.GetEntity(); 
    int nEntityIdx = pEntity.entindex();
    CBackupFrostNadePlayerData@ pBackupData = g_rglpBackupFrostNadePlayerData[nEntityIdx];
    
    if (!g_abIsZombieFrozen[nEntityIdx]) {
        pEntity.pev.renderfx = pBackupData.m_iRenderFX;
        pEntity.pev.rendercolor = pBackupData.m_vecRenderColor;
        pEntity.pev.rendermode = pBackupData.m_iRenderMode;
        pEntity.pev.renderamt = pBackupData.m_flRenderAmount;
        pEntity.pev.velocity = pBackupData.m_vecOriginalVelocity;
        return;
    }
    
    //Reserved for future: Antidot. ~ xWhitey
    if (!g_abZombies[nEntityIdx]) {
        return;
    }
    
    pEntity.pev.origin = pBackupData.m_vecOriginalOrigin;
    pEntity.pev.velocity = g_vecZero;
    g_PlayerFuncs.ScreenFade(pEntity, Vector(0, 50, 200), 0, 0, 100, FFADE_STAYOUT);
     
    @g_rglpfnFrozenLoops[nEntityIdx] = g_Scheduler.SetTimeout("ZM_FrostGrenade_KeepFrozen", 0.0f, EHandle(pEntity));
}

void ZM_FrostGrenade_UnfreezeZombie(EHandle _Zombie) {
    if (!_Zombie.IsValid())
        return;
        
    CBaseEntity@ pEntity = _Zombie.GetEntity(); 
    int nEntityIdx = pEntity.entindex();
    
    g_abIsZombieFrozen[nEntityIdx] = false;
    g_PlayerFuncs.ScreenFade(pEntity, Vector(0, 50, 200), 1.0f, 0, 100, FFADE_IN);
    g_SoundSystem.EmitSound(pEntity.edict(), CHAN_BODY, "zombie_plague/warcraft3/impalelaunch1.wav", 1.0f, ATTN_NORM);
    // Glass shatter
	NetworkMessage glassGibs(MSG_PVS, NetworkMessages::SVC_TEMPENTITY, pEntity.pev.origin);
        glassGibs.WriteByte(TE_BREAKMODEL); // TE id
        glassGibs.WriteCoord(pEntity.pev.origin.x); // x
        glassGibs.WriteCoord(pEntity.pev.origin.y); // y
        glassGibs.WriteCoord(pEntity.pev.origin.z + 24.f); // z
        glassGibs.WriteCoord(16); // size x
        glassGibs.WriteCoord(16); // size y
        glassGibs.WriteCoord(16); // size z
        glassGibs.WriteCoord(float(Math.RandomLong(-50, 50))); // velocity x
        glassGibs.WriteCoord(float(Math.RandomLong(-50, 50))); // velocity y
        glassGibs.WriteCoord(25); // velocity z
        glassGibs.WriteByte(10); // random velocity
        glassGibs.WriteShort(g_EngineFuncs.ModelIndex("models/glassgibs.mdl")); // model
        glassGibs.WriteByte(10); // count
        glassGibs.WriteByte(25); // life
        glassGibs.WriteByte(1); // flags
	glassGibs.End();
}

class CZombieInfectionGrenade : ScriptBaseEntity {
    bool m_bRegisteredSound = false;
    
    protected Vector m_vecTrailAndGlowColour;
    int m_iMode;
    protected Vector m_vecLastOrigin;
    protected Vector m_vecTripLaserEndPos;
    protected float m_flBeamLength;
    
    CZombieInfectionGrenade() {
        m_vecTrailAndGlowColour = Vector(0, 200, 0);
        m_vecLastOrigin = g_vecZero;
        m_vecTripLaserEndPos = g_vecZero;
        m_flBeamLength = 0.f;
    }
	
	void Spawn() {
		Precache();
		
		self.pev.movetype = MOVETYPE_BOUNCE;
		self.pev.solid = SOLID_BBOX;
        
        self.pev.gravity = 0.55f;
		self.pev.friction = 0.7f;
		self.pev.framerate = 1.0f;
		
		g_EntityFuncs.SetSize(self.pev, Vector(-1, -1, -1), Vector(1, 1, 1));
		
		m_bRegisteredSound = false;
	}
	
	void Precache() {
        g_Game.PrecacheModel("sprites/laserbeam.spr");
        g_Game.PrecacheModel("sprites/zombie_plague/fexplo.spr");
        g_Game.PrecacheModel("sprites/zombie_plague/zombiebomb_exp.spr");
        g_Game.PrecacheModel("sprites/shockwave.spr");
        
        g_Game.PrecacheGeneric("sound/zombie_plague/grenade_explode.wav");
        g_SoundSystem.PrecacheSound("zombie_plague/grenade_explode.wav");
        
        g_Game.PrecacheGeneric("sound/zombie_plague/cs/grenade/bounce.wav");
		g_SoundSystem.PrecacheSound("zombie_plague/cs/grenade/bounce.wav");
        
        g_Game.PrecacheGeneric("sound/weapons/mine_deploy.wav");
        g_SoundSystem.PrecacheSound("weapons/mine_deploy.wav");
        g_Game.PrecacheGeneric("sound/weapons/mine_charge.wav");
        g_SoundSystem.PrecacheSound("weapons/mine_charge.wav");
        g_Game.PrecacheGeneric("sound/weapons/mine_activate.wav");
        g_SoundSystem.PrecacheSound("weapons/mine_activate.wav");
	}
	
	void BounceTouch(CBaseEntity@ pOther) {
		if (pOther.edict() is self.pev.owner)
			return;
        
        if (self.pev.velocity.Length() != 0) {
            if (self.pev.owner !is null) {
                entvars_t@ pevOwner = self.pev.owner.vars;
                if (pevOwner !is null) {
                    TraceResult tr = g_Utility.GetGlobalTrace();
                    g_WeaponFuncs.ClearMultiDamage();
                    pOther.TraceAttack(pevOwner, 1, g_Engine.v_forward, tr, DMG_BLAST);
                    g_WeaponFuncs.ApplyMultiDamage(self.pev, pevOwner);
                }
            }
        }
        
        if ((self.pev.flags & FL_ONGROUND) == 0) {
            // play bounce sound
            BounceSound();
        }
        
        switch (m_iMode) {
            case 0: { //Normal
                Vector vecTestVelocity;
                
                vecTestVelocity = self.pev.velocity; 
                vecTestVelocity.z *= 0.45;
                
                if (!m_bRegisteredSound && vecTestVelocity.Length() <= 60) {
                    CBaseEntity@ pOwner = g_EntityFuncs.Instance(self.pev.owner);
                    CSoundEnt@ soundEnt = GetSoundEntInstance();
                    soundEnt.InsertSound(bits_SOUND_DANGER, self.pev.origin, int(self.pev.dmg / 0.4), 0.3, pOwner);
                    m_bRegisteredSound = true;
                }
            }
                break;
            case 1: { //Proximity
                //Does nothing in Proximity.
            }
                break;
            case 2: { //Impact
                SetThink(ThinkFunction(Detonate));
                self.pev.nextthink = g_Engine.time + 0.1f;
            }
                break;
            case 3: { //Trip laser
                if (pOther.GetClassname() == "worldspawn") {
                    m_vecLastOrigin = self.pev.origin;
                    self.pev.movetype = MOVETYPE_NONE;
                    TraceResult tr;
                    float flForward = ZM_UTIL_Degree2Radians(self.pev.angles.y);
                    g_Utility.TraceLine(self.pev.origin, Vector(self.pev.origin.x + cos(flForward) * 8192.0f, self.pev.origin.y + sin(flForward) * 8192.0f, self.pev.origin.z), dont_ignore_monsters, self.edict(), tr);
                    //self.pev.angles = Math.VecToAngles(tr.vecPlaneNormal);
                    self.pev.angles = Vector(((asin(tr.vecPlaneNormal.z) * -1.f) * (180.f / g_flPI)), atan2(tr.vecPlaneNormal.y, tr.vecPlaneNormal.x) * (180.f / g_flPI), 0.f);
                    Math.MakeVectors(self.pev.angles);
                    self.pev.angles = Math.VecToAngles(g_Engine.v_forward);
                    SetThink(ThinkFunction(MineActivate));
                    self.pev.nextthink = g_Engine.time + 2.5f;
                    self.pev.solid = SOLID_NOT;
                    @self.pev.owner = null;
                    g_SoundSystem.EmitSound(self.edict(), CHAN_VOICE, "weapons/mine_deploy.wav", 1.0f, ATTN_NORM);
                    g_SoundSystem.EmitSound(self.edict(), CHAN_BODY, "weapons/mine_charge.wav", 0.2f, ATTN_NORM);
                }
            }
                break;
            case 4: { //Motion sensor
                //Does nothing in Motion sensor.
            }
                break;
            case 5: { //Satchel charge
            }
                break;
            case 6: { //Homing
            }
                break;
        }
		
		self.pev.framerate = self.pev.velocity.Length() / 200.0;
		if (self.pev.framerate > 1.0)
			self.pev.framerate = 1;
		else if (self.pev.framerate < 0.5)
			self.pev.framerate = 0;
	}
    
    void MineActivate() {
        g_SoundSystem.EmitSoundDyn(self.edict(), CHAN_VOICE, "weapons/mine_activate.wav", 0.5f, ATTN_NORM, 1.0, 75);
        TraceResult tr;
        float sp = sin(ZM_UTIL_Degree2Radians(self.pev.angles.x));
        float sy = sin(ZM_UTIL_Degree2Radians(self.pev.angles.y));

        float cp = cos(ZM_UTIL_Degree2Radians(self.pev.angles.x));
        float cy = cos(ZM_UTIL_Degree2Radians(self.pev.angles.y));
                
        Vector vecEndpoint(self.pev.origin.x + 8192.f * cp * cy, self.pev.origin.y + 8192.f * cp * sy, self.pev.origin.z + 8192.f * sp);
        g_Utility.TraceLine(self.pev.origin, vecEndpoint, dont_ignore_monsters, self.edict(), tr);
        m_vecTripLaserEndPos = tr.vecEndPos;
        m_flBeamLength = tr.flFraction;
        SetThink(ThinkFunction(TumbleThink));
        self.pev.nextthink = g_Engine.time + 0.1f;
    }
	
	void TumbleThink() {
		if (!self.IsInWorld()) {
			g_EntityFuncs.Remove(self);
			return;
		}
        
        NetworkMessage m(MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY);
            m.WriteByte(TE_BEAMFOLLOW);
            m.WriteShort(self.entindex());
            m.WriteShort(g_EngineFuncs.ModelIndex("sprites/laserbeam.spr"));
            m.WriteByte(10);
            m.WriteByte(10);
            m.WriteByte(int(m_vecTrailAndGlowColour.x)); //r
            m.WriteByte(int(m_vecTrailAndGlowColour.y)); //g
            m.WriteByte(int(m_vecTrailAndGlowColour.z)); //b
            m.WriteByte(200); //brightness
        m.End();
        
        self.pev.renderfx = kRenderFxGlowShell;
        self.pev.renderamt = 16;
        self.pev.rendercolor = m_vecTrailAndGlowColour;
        
        switch (m_iMode) {
            case 0: { //Normal
                //self.StudioFrameAdvance();
                self.pev.nextthink = g_Engine.time + 0.1f;
                
                if ((self.pev.flags & FL_ONGROUND) != 0) {
                    self.pev.velocity.x *= 0.6f;
                    self.pev.velocity.y *= 0.6f;
                
                    self.pev.sequence = 1;
                }
                
                if (self.pev.dmgtime - 1 < g_Engine.time) {
                    CBaseEntity@ pOwner = g_EntityFuncs.Instance(self.pev.owner);
                    CSoundEnt@ soundEnt = GetSoundEntInstance();
                    soundEnt.InsertSound(bits_SOUND_DANGER, self.pev.origin + self.pev.velocity * (self.pev.dmgtime - g_Engine.time), 400, 0.1, pOwner);
                }
                
                if (self.pev.dmgtime <= g_Engine.time) {
                    SetThink(ThinkFunction(Detonate));
                }
            }
                break;
            case 1: { //Proximity
                if ((self.pev.flags & FL_ONGROUND) != 0) {
                    self.pev.velocity.x *= 0.6f;
                    self.pev.velocity.y *= 0.6f;
                
                    self.pev.sequence = 1;
                }
            
                CBaseEntity@ pEntity = null;
                while ((@pEntity = g_EntityFuncs.FindEntityInSphere(pEntity, self.pev.origin, 200.f /* radius */, "player", "classname")) !is null) {
                    if (!pEntity.IsPlayer()) {
                        continue;
                    }
                    if (!pEntity.IsAlive()) {
                        continue;
                    }
                        
                    int nPlayerIdx = pEntity.entindex();
                    if (g_abZombies[nPlayerIdx]) {
                        continue;
                    }
                    
                    SetThink(ThinkFunction(Detonate));
                    break;
                }
                        
                self.pev.nextthink = g_Engine.time + 0.1f;
            }
                break;
            case 2: { //Impact
                if ((self.pev.flags & FL_ONGROUND) != 0) {
                    self.pev.velocity.x *= 0.6f;
                    self.pev.velocity.y *= 0.6f;
                
                    self.pev.sequence = 1;
                }
                
                self.pev.nextthink = g_Engine.time + 0.1f;
            }
                break;
            case 3: { //Trip laser
                if (m_vecLastOrigin == g_vecZero) {
                    self.pev.nextthink = g_Engine.time + 0.1f; //do nothing until we are on some surface
                    return;
                }
                self.pev.velocity = g_vecZero;
                self.pev.sequence = 0;
                
                TraceResult tr;
                float sp = sin(ZM_UTIL_Degree2Radians(self.pev.angles.x));
                float sy = sin(ZM_UTIL_Degree2Radians(self.pev.angles.y));

                float cp = cos(ZM_UTIL_Degree2Radians(self.pev.angles.x));
                float cy = cos(ZM_UTIL_Degree2Radians(self.pev.angles.y));
                        
                Vector vecEndpoint(self.pev.origin.x + 8192.f * cp * cy, self.pev.origin.y + 8192.f * cp * sy, self.pev.origin.z + 8192.f * sp);
                g_Utility.TraceLine(self.pev.origin, vecEndpoint, dont_ignore_monsters, self.edict(), tr);
                if (fabsf(m_flBeamLength - tr.flFraction) > 0.001 || tr.flFraction <= 1.0f || tr.vecEndPos != m_vecTripLaserEndPos) {
                    CBaseEntity@ pEntity = g_EntityFuncs.Instance(tr.pHit);
                    if ((pEntity !is null && pEntity.pev !is null) || tr.vecEndPos != m_vecTripLaserEndPos) {
                        if (pEntity.GetClassname() != "worldspawn") {
                            if (pEntity.IsPlayer()) {
                                if (!g_abZombies[pEntity.entindex()]) {
                                    SetThink(ThinkFunction(Detonate));
                                }
                            }
                        }
                    }
                    NetworkMessage beam(MSG_PVS, NetworkMessages::SVC_TEMPENTITY, self.pev.origin);
                        beam.WriteByte(TE_BEAMPOINTS); // TE id
                        beam.WriteCoord(self.pev.origin.x); //x
                        beam.WriteCoord(self.pev.origin.y); //y
                        beam.WriteCoord(self.pev.origin.z); //z
                        beam.WriteCoord(m_vecTripLaserEndPos.x); //x axis
                        beam.WriteCoord(m_vecTripLaserEndPos.y); //y axis
                        beam.WriteCoord(m_vecTripLaserEndPos.z); //z axis
                        beam.WriteShort(g_EngineFuncs.ModelIndex("sprites/laserbeam.spr")); // sprite
                        beam.WriteByte(0); // startframe
                        beam.WriteByte(0); // framerate
                        beam.WriteByte(2); // life
                        beam.WriteByte(5); // width
                        beam.WriteByte(0); // noise
                        beam.WriteByte(0); // red
                        beam.WriteByte(0); // green
                        beam.WriteByte(255); // blue
                        beam.WriteByte(200); // brightness
                        beam.WriteByte(0); // speed
                    beam.End();
                }
                
                self.pev.nextthink = g_Engine.time + 0.03f;
            }
                break;
            case 4: { //Motion sensor
                if ((self.pev.flags & FL_ONGROUND) != 0) {
                    self.pev.velocity.x *= 0.6f;
                    self.pev.velocity.y *= 0.6f;
                
                    self.pev.sequence = 1;
                }
            
                CBaseEntity@ pEntity = null;
                while ((@pEntity = g_EntityFuncs.FindEntityInSphere(pEntity, self.pev.origin, 240.f /* radius */, "player", "classname")) !is null) {
                    if (!pEntity.IsPlayer()) {
                        continue;
                    }
                    if (!pEntity.IsAlive()) {
                        continue;
                    }
                        
                    int nPlayerIdx = pEntity.entindex();
                    if (g_abZombies[nPlayerIdx]) {
                        continue;
                    }
                    
                    if (pEntity.pev.velocity.Length() > 135.f) { //More than with +duck or +speed
                        SetThink(ThinkFunction(Detonate));
                        self.pev.nextthink = g_Engine.time + 0.1f;
                        break;
                    }
                }
                    
                self.pev.nextthink = g_Engine.time + 0.1f;
            }
                break;
            case 5: { //Satchel charge
                if ((self.pev.flags & FL_ONGROUND) != 0) {
                    self.pev.velocity.x *= 0.6f;
                    self.pev.velocity.y *= 0.6f;
                
                    self.pev.sequence = 1;
                }
                
                self.pev.nextthink = g_Engine.time + 0.1f;
            }
                break;
            case 6: { //Homing
                if ((self.pev.flags & FL_ONGROUND) != 0) {
                    self.pev.velocity.x *= 0.6f;
                    self.pev.velocity.y *= 0.6f;
                
                    self.pev.sequence = 1;
                }
                
                self.pev.nextthink = g_Engine.time + 0.1f;
            }
                break;
        }
		
		if (self.pev.waterlevel != 0) {
			self.pev.velocity = self.pev.velocity * 0.5;
			self.pev.framerate = 0.2;
            self.pev.angles = Math.VecToAngles(self.pev.velocity);
		}
	}
    
    void SatchelDetonate() {
        SetThink(ThinkFunction(Detonate));
    
        self.pev.nextthink = g_Engine.time + 0.1f;
    }
    
    void CreateExplosionRing(const Vector& in _Origin) {
        // Smallest ring
        NetworkMessage smallest_ring(MSG_PVS, NetworkMessages::SVC_TEMPENTITY, _Origin);
            smallest_ring.WriteByte(TE_BEAMCYLINDER); // TE id
            smallest_ring.WriteCoord(_Origin.x); //x
            smallest_ring.WriteCoord(_Origin.y); //y
            smallest_ring.WriteCoord(_Origin.z); //z
            smallest_ring.WriteCoord(_Origin.x); //x axis
            smallest_ring.WriteCoord(_Origin.y); //y axis
            smallest_ring.WriteCoord(_Origin.z + 385.f); //z axis
            smallest_ring.WriteShort(g_EngineFuncs.ModelIndex("sprites/shockwave.spr")); // sprite
            smallest_ring.WriteByte(0); // startframe
            smallest_ring.WriteByte(0); // framerate
            smallest_ring.WriteByte(4); // life
            smallest_ring.WriteByte(60); // width
            smallest_ring.WriteByte(0); // noise
            smallest_ring.WriteByte(0); // red
            smallest_ring.WriteByte(200); // green
            smallest_ring.WriteByte(0); // blue
            smallest_ring.WriteByte(200); // brightness
            smallest_ring.WriteByte(0); // speed
        smallest_ring.End();
        
        // Medium ring
        NetworkMessage medium_ring(MSG_PVS, NetworkMessages::SVC_TEMPENTITY, _Origin);
            medium_ring.WriteByte(TE_BEAMCYLINDER); // TE id
            medium_ring.WriteCoord(_Origin.x); //x
            medium_ring.WriteCoord(_Origin.y); //y
            medium_ring.WriteCoord(_Origin.z); //z
            medium_ring.WriteCoord(_Origin.x); //x axis
            medium_ring.WriteCoord(_Origin.y); //y axis
            medium_ring.WriteCoord(_Origin.z + 470.f); //z axis
            medium_ring.WriteShort(g_EngineFuncs.ModelIndex("sprites/shockwave.spr")); // sprite
            medium_ring.WriteByte(0); // startframe
            medium_ring.WriteByte(0); // framerate
            medium_ring.WriteByte(4); // life
            medium_ring.WriteByte(60); // width
            medium_ring.WriteByte(0); // noise
            medium_ring.WriteByte(0); // red
            medium_ring.WriteByte(100); // green
            medium_ring.WriteByte(0); // blue
            medium_ring.WriteByte(200); // brightness
            medium_ring.WriteByte(0); // speed
        medium_ring.End();
        
        // Largest ring
        NetworkMessage largest_ring(MSG_PVS, NetworkMessages::SVC_TEMPENTITY, _Origin);
            largest_ring.WriteByte(TE_BEAMCYLINDER); // TE id
            largest_ring.WriteCoord(_Origin.x); //x
            largest_ring.WriteCoord(_Origin.y); //y
            largest_ring.WriteCoord(_Origin.z); //z
            largest_ring.WriteCoord(_Origin.x); //x axis
            largest_ring.WriteCoord(_Origin.y); //y axis
            largest_ring.WriteCoord(_Origin.z + 555.f); //z axis
            largest_ring.WriteShort(g_EngineFuncs.ModelIndex("sprites/shockwave.spr")); // sprite
            largest_ring.WriteByte(0); // startframe
            largest_ring.WriteByte(0); // framerate
            largest_ring.WriteByte(4); // life
            largest_ring.WriteByte(60); // width
            largest_ring.WriteByte(0); // noise
            largest_ring.WriteByte(0); // red
            largest_ring.WriteByte(50); // green
            largest_ring.WriteByte(0); // blue
            largest_ring.WriteByte(200); // brightness
            largest_ring.WriteByte(0); // speed
        largest_ring.End();
    }
	
	void Detonate() {
        CreateExplosionRing(self.pev.origin);
        
        NetworkMessage explosion(MSG_PVS, NetworkMessages::SVC_TEMPENTITY, self.pev.origin);
            explosion.WriteByte(TE_SPRITE); // TE id
            explosion.WriteCoord(self.pev.origin.x); //x
            explosion.WriteCoord(self.pev.origin.y); //y
            explosion.WriteCoord(self.pev.origin.z); //z
            explosion.WriteShort(g_EngineFuncs.ModelIndex("sprites/zombie_plague/zombiebomb_exp.spr")); // sprite
            //https://github.com/twhl-community/halflife-op4-updated/blob/97b5412dd064bcab44624eff58bd6b993281ae53/dlls/weapons/CSpore.cpp#L173
            explosion.WriteByte(100); // scale
            explosion.WriteByte(200); // brightness
        explosion.End();
        
        g_SoundSystem.EmitSound(self.edict(), CHAN_WEAPON, "zombie_plague/grenade_explode.wav", 1.0f, ATTN_NORM);
        
        CBaseEntity@ pEntity = null;
        while ((@pEntity = g_EntityFuncs.FindEntityInSphere(pEntity, self.pev.origin, 240.f /* radius */, "player", "classname")) !is null) {
            if (!pEntity.IsPlayer()) {
                continue;
            }
            if (!pEntity.IsAlive()) {
                continue;
            }
                
            int nPlayerIdx = pEntity.entindex();
            if (g_abZombies[nPlayerIdx]) {
                continue;
            }
            
            if (ZM_UTIL_CountAlivePlayers() == 1) {
                break;
            }
            
            CBasePlayer@ pPlayer = cast<CBasePlayer@>(pEntity);
            
            g_ahZombies.insertLast(EHandle(pPlayer));
            ZM_UTIL_TurnPlayerIntoAZombie(pPlayer);
        }
        
        g_EntityFuncs.Remove(self);
	}
	
	void BounceSound() {
		g_SoundSystem.EmitSound(self.edict(), CHAN_VOICE, "zombie_plague/cs/grenade/bounce.wav", 0.50f, ATTN_NORM);
	}
}

void ZM_UTIL_SetPlayerSpeedBasedOnLength(const Vector& in _P1, const Vector& in _P2, float _Speed, Vector& out _OutSpeed) {
	_OutSpeed.x = _P2.x - _P1.x;
	_OutSpeed.y = _P2.y - _P1.y;
	_OutSpeed.z = _P2.z - _P1.z;
	float flDelta = sqrt((_Speed * _Speed) / _OutSpeed.Length());
	_OutSpeed[0] *= flDelta;
	_OutSpeed[1] *= flDelta;
	_OutSpeed[2] *= flDelta;
}

class CZombieJumpGrenade : ScriptBaseEntity {
    bool m_bRegisteredSound = false;
    
    protected Vector m_vecTrailAndGlowColour;
    
    CZombieJumpGrenade() {
        m_vecTrailAndGlowColour = Vector(147, 168, 50);
    }
	
	void Spawn() {
		Precache();
		
		self.pev.movetype = MOVETYPE_BOUNCE;
		self.pev.solid = SOLID_BBOX;
        
        self.pev.gravity = 0.55f;
		self.pev.friction = 0.7f;
		self.pev.framerate = 1.0f;
		
		g_EntityFuncs.SetSize(self.pev, Vector(-1, -1, -1), Vector(1, 1, 1));
		
		m_bRegisteredSound = false;
	}
	
	void Precache() {
        g_Game.PrecacheModel("sprites/zombie_plague/fexplo.spr");
        g_Game.PrecacheModel("sprites/zombie_plague/zombiebomb_exp.spr");
        
        g_Game.PrecacheGeneric("sound/weapons/splauncher_bounce.wav");
        g_SoundSystem.PrecacheSound("weapons/splauncher_bounce.wav");
        
        g_Game.PrecacheGeneric("sound/weapons/splauncher_bounce.wav");
        g_SoundSystem.PrecacheSound("weapons/splauncher_bounce.wav");
        
        g_Game.PrecacheGeneric("sound/nst_zombie/zombi_bomb_exp.wav");
        g_SoundSystem.PrecacheSound("nst_zombie/zombi_bomb_exp.wav");
        g_Game.PrecacheGeneric("sound/nst_zombie/zombi_bomb_pull_1.wav");
        g_SoundSystem.PrecacheSound("nst_zombie/zombi_bomb_pull_1.wav");
        g_Game.PrecacheGeneric("sound/nst_zombie/zombi_bomb_deploy.wav");
        g_SoundSystem.PrecacheSound("nst_zombie/zombi_bomb_deploy.wav");
        g_Game.PrecacheGeneric("sound/nst_zombie/zombi_bomb_throw.wav");
        g_SoundSystem.PrecacheSound("nst_zombie/zombi_bomb_throw.wav");
        
        g_Game.PrecacheGeneric("sound/nst_zombie/zombi_bomb_idle_1.wav");
        g_SoundSystem.PrecacheSound("nst_zombie/zombi_bomb_idle_1.wav");
        g_Game.PrecacheGeneric("sound/nst_zombie/zombi_bomb_idle_2.wav");
        g_SoundSystem.PrecacheSound("nst_zombie/zombi_bomb_idle_2.wav");
        g_Game.PrecacheGeneric("sound/nst_zombie/zombi_bomb_idle_3.wav");
        g_SoundSystem.PrecacheSound("nst_zombie/zombi_bomb_idle_3.wav");
        g_Game.PrecacheGeneric("sound/nst_zombie/zombi_bomb_idle_4.wav");
        g_SoundSystem.PrecacheSound("nst_zombie/zombi_bomb_idle_4.wav");
	}
	
	void BounceTouch(CBaseEntity@ pOther) {
		if (pOther.edict() is self.pev.owner)
			return;
        
        if (self.pev.velocity.Length() != 0) {
            if (self.pev.owner !is null) {
                entvars_t@ pevOwner = self.pev.owner.vars;
                if (pevOwner !is null) {
                    TraceResult tr = g_Utility.GetGlobalTrace();
                    g_WeaponFuncs.ClearMultiDamage();
                    pOther.TraceAttack(pevOwner, 1, g_Engine.v_forward, tr, DMG_BLAST);
                    g_WeaponFuncs.ApplyMultiDamage(self.pev, pevOwner);
                }
            }
        }
        
        if ((self.pev.flags & FL_ONGROUND) == 0) {
            // play bounce sound
            BounceSound();
        }
        
        Vector vecTestVelocity;
                
        vecTestVelocity = self.pev.velocity; 
        vecTestVelocity.z *= 0.45;
                
        if (!m_bRegisteredSound && vecTestVelocity.Length() <= 60) {
            CBaseEntity@ pOwner = g_EntityFuncs.Instance(self.pev.owner);
            CSoundEnt@ soundEnt = GetSoundEntInstance();
            soundEnt.InsertSound(bits_SOUND_DANGER, self.pev.origin, int(self.pev.dmg / 0.4), 0.3, pOwner);
            m_bRegisteredSound = true;
        }
		
		self.pev.framerate = self.pev.velocity.Length() / 200.0;
		if (self.pev.framerate > 1.0)
			self.pev.framerate = 1;
		else if (self.pev.framerate < 0.5)
			self.pev.framerate = 0;
	}
	
	void TumbleThink() {
		if (!self.IsInWorld()) {
			g_EntityFuncs.Remove(self);
			return;
		}
        
        NetworkMessage m(MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY);
            m.WriteByte(TE_BEAMFOLLOW);
            m.WriteShort(self.entindex());
            m.WriteShort(g_EngineFuncs.ModelIndex("sprites/laserbeam.spr"));
            m.WriteByte(10);
            m.WriteByte(10);
            m.WriteByte(int(m_vecTrailAndGlowColour.x)); //r
            m.WriteByte(int(m_vecTrailAndGlowColour.y)); //g
            m.WriteByte(int(m_vecTrailAndGlowColour.z)); //b
            m.WriteByte(200); //brightness
        m.End();
        
        self.pev.renderfx = kRenderFxGlowShell;
        self.pev.renderamt = 16;
        self.pev.rendercolor = m_vecTrailAndGlowColour;
        
        
        //self.StudioFrameAdvance();
        self.pev.nextthink = g_Engine.time + 0.1f;
                
        if ((self.pev.flags & FL_ONGROUND) != 0) {
            self.pev.velocity.x *= 0.6f;
            self.pev.velocity.y *= 0.6f;
                
            self.pev.sequence = 1;
        }
                
        if (self.pev.dmgtime - 1 < g_Engine.time) {
            CBaseEntity@ pOwner = g_EntityFuncs.Instance(self.pev.owner);
            CSoundEnt@ soundEnt = GetSoundEntInstance();
            soundEnt.InsertSound(bits_SOUND_DANGER, self.pev.origin + self.pev.velocity * (self.pev.dmgtime - g_Engine.time), 400, 0.1, pOwner);
        }
    
        if (self.pev.dmgtime <= g_Engine.time) {
            SetThink(ThinkFunction(Detonate));
        }
		
		if (self.pev.waterlevel != 0) {
			self.pev.velocity = self.pev.velocity * 0.5;
			self.pev.framerate = 0.2;
            self.pev.angles = Math.VecToAngles(self.pev.velocity);
		}
	}
	
	void Detonate() {
        NetworkMessage explosion(MSG_PVS, NetworkMessages::SVC_TEMPENTITY, self.pev.origin);
            explosion.WriteByte(TE_SPRITE); // TE id
            explosion.WriteCoord(self.pev.origin.x); //x
            explosion.WriteCoord(self.pev.origin.y); //y
            explosion.WriteCoord(self.pev.origin.z); //z
            explosion.WriteShort(g_EngineFuncs.ModelIndex("sprites/zombie_plague/zombiebomb_exp.spr")); // sprite
            //https://github.com/twhl-community/halflife-op4-updated/blob/97b5412dd064bcab44624eff58bd6b993281ae53/dlls/weapons/CSpore.cpp#L173
            explosion.WriteByte(20); // startframe?
            explosion.WriteByte(128); // ?
        explosion.End();
        
        g_SoundSystem.EmitSound(self.edict(), CHAN_WEAPON, "nst_zombie/zombi_bomb_exp.wav", 1.0f, ATTN_NORM);
        
        //By default, this entity pushes by 500 units (if standing in the center)
        CBaseEntity@ pEntity = null;
        while ((@pEntity = g_EntityFuncs.FindEntityInSphere(pEntity, self.pev.origin, 300.f /* radius */, "player", "classname")) !is null) {
            if (!pEntity.IsPlayer()) {
                continue;
            }
            if (!pEntity.IsAlive()) {
                continue;
            }
                
            int nPlayerIdx = pEntity.entindex();
            if (g_abZombies[nPlayerIdx]) {
                continue;
            }
            
            CBasePlayer@ pPlayer = cast<CBasePlayer@>(pEntity);
            
            float flNewSpeed = 500.f * (1.f - ((pPlayer.pev.origin - self.pev.origin).Length())); 
            ZM_UTIL_SetPlayerSpeedBasedOnLength(self.pev.origin, pPlayer.pev.origin, flNewSpeed, pPlayer.pev.velocity);
        }
        
        g_EntityFuncs.Remove(self);
	}
    
    void BounceSound() {
		g_SoundSystem.EmitSound(self.edict(), CHAN_VOICE, "weapons/splauncher_bounce.wav", 0.50f, ATTN_NORM);
	}
}

CCustomGrenade@ ZM_UTIL_ShootGrenade(entvars_t@ pevOwner, Vector vecStart, Vector vecVelocity, float flTime, float flDmg, string sModel, const string& in szName, int iMode) {
	CBaseEntity@ pEntity = g_EntityFuncs.CreateEntity(szName);
	CCustomGrenade@ pCustomGrenade = cast<CCustomGrenade@>(CastToScriptClass(pEntity));

	g_EntityFuncs.SetOrigin(pCustomGrenade.self, vecStart);
	g_EntityFuncs.SetModel(pCustomGrenade.self, sModel);
	g_EntityFuncs.DispatchSpawn(pCustomGrenade.self.edict());

	pCustomGrenade.pev.velocity = vecVelocity;
	pCustomGrenade.pev.angles = Math.VecToAngles(pCustomGrenade.pev.velocity);
	@pCustomGrenade.pev.owner = pevOwner.pContainingEntity;
    
    pCustomGrenade.m_iMode = iMode;

	pCustomGrenade.pev.dmg = flDmg;
	pCustomGrenade.pev.sequence = Math.RandomLong(3, 6);

	pCustomGrenade.SetTouch(TouchFunction(pCustomGrenade.BounceTouch));
	pCustomGrenade.SetThink(ThinkFunction(pCustomGrenade.TumbleThink));
	pCustomGrenade.pev.nextthink = g_Engine.time + 0.1f;
	pCustomGrenade.pev.dmgtime = g_Engine.time + flTime;

	return pCustomGrenade;
}

CCustomFireGrenade@ ZM_UTIL_ShootFireGrenade(entvars_t@ pevOwner, Vector vecStart, Vector vecVelocity, float flTime, float flDmg, string sModel, const string& in szName, int iMode) {
	CBaseEntity@ pEntity = g_EntityFuncs.CreateEntity(szName);
	CCustomFireGrenade@ pCustomGrenade = cast<CCustomFireGrenade@>(CastToScriptClass(pEntity));

	g_EntityFuncs.SetOrigin(pCustomGrenade.self, vecStart);
	g_EntityFuncs.SetModel(pCustomGrenade.self, sModel);
	g_EntityFuncs.DispatchSpawn(pCustomGrenade.self.edict());

	pCustomGrenade.pev.velocity = vecVelocity;
	pCustomGrenade.pev.angles = Math.VecToAngles(pCustomGrenade.pev.velocity);
	@pCustomGrenade.pev.owner = pevOwner.pContainingEntity;
    
    pCustomGrenade.m_iMode = iMode;

	pCustomGrenade.pev.dmg = flDmg;
	pCustomGrenade.pev.sequence = Math.RandomLong(3, 6);

	pCustomGrenade.SetTouch(TouchFunction(pCustomGrenade.BounceTouch));
	pCustomGrenade.SetThink(ThinkFunction(pCustomGrenade.TumbleThink));
	pCustomGrenade.pev.nextthink = g_Engine.time + 0.1f;
	pCustomGrenade.pev.dmgtime = g_Engine.time + flTime;

	return pCustomGrenade;
}

CCustomFrostGrenade@ ZM_UTIL_ShootFrostGrenade(entvars_t@ pevOwner, Vector vecStart, Vector vecVelocity, float flTime, float flDmg, string sModel, const string& in szName, int iMode) {
	CBaseEntity@ pEntity = g_EntityFuncs.CreateEntity(szName);
	CCustomFrostGrenade@ pCustomGrenade = cast<CCustomFrostGrenade@>(CastToScriptClass(pEntity));

	g_EntityFuncs.SetOrigin(pCustomGrenade.self, vecStart);
	g_EntityFuncs.SetModel(pCustomGrenade.self, sModel);
	g_EntityFuncs.DispatchSpawn(pCustomGrenade.self.edict());

	pCustomGrenade.pev.velocity = vecVelocity;
	pCustomGrenade.pev.angles = Math.VecToAngles(pCustomGrenade.pev.velocity);
	@pCustomGrenade.pev.owner = pevOwner.pContainingEntity;
    
    pCustomGrenade.m_iMode = iMode;

	pCustomGrenade.pev.dmg = flDmg;
	pCustomGrenade.pev.sequence = Math.RandomLong(3, 6);

	pCustomGrenade.SetTouch(TouchFunction(pCustomGrenade.BounceTouch));
	pCustomGrenade.SetThink(ThinkFunction(pCustomGrenade.TumbleThink));
	pCustomGrenade.pev.nextthink = g_Engine.time + 0.1f;
	pCustomGrenade.pev.dmgtime = g_Engine.time + flTime;

	return pCustomGrenade;
}

CZombieInfectionGrenade@ ZM_UTIL_ShootZombieInfectionGrenade(entvars_t@ pevOwner, Vector vecStart, Vector vecVelocity, float flTime, float flDmg, string sModel, const string& in szName, int iMode) {
	CBaseEntity@ pEntity = g_EntityFuncs.CreateEntity(szName);
	CZombieInfectionGrenade@ pCustomGrenade = cast<CZombieInfectionGrenade@>(CastToScriptClass(pEntity));

	g_EntityFuncs.SetOrigin(pCustomGrenade.self, vecStart);
	g_EntityFuncs.SetModel(pCustomGrenade.self, sModel);
	g_EntityFuncs.DispatchSpawn(pCustomGrenade.self.edict());

	pCustomGrenade.pev.velocity = vecVelocity;
	pCustomGrenade.pev.angles = Math.VecToAngles(pCustomGrenade.pev.velocity);
	@pCustomGrenade.pev.owner = pevOwner.pContainingEntity;
    
    pCustomGrenade.m_iMode = iMode;

	pCustomGrenade.pev.dmg = flDmg;
	pCustomGrenade.pev.sequence = Math.RandomLong(3, 6);

	pCustomGrenade.SetTouch(TouchFunction(pCustomGrenade.BounceTouch));
	pCustomGrenade.SetThink(ThinkFunction(pCustomGrenade.TumbleThink));
	pCustomGrenade.pev.nextthink = g_Engine.time + 0.1f;
	pCustomGrenade.pev.dmgtime = g_Engine.time + flTime;

	return pCustomGrenade;
}

CZombieJumpGrenade@ ZM_UTIL_ShootZombieJumpGrenade(entvars_t@ pevOwner, Vector vecStart, Vector vecVelocity, float flTime, float flDmg, string sModel, const string& in szName) {
	CBaseEntity@ pEntity = g_EntityFuncs.CreateEntity(szName);
	CZombieJumpGrenade@ pCustomGrenade = cast<CZombieJumpGrenade@>(CastToScriptClass(pEntity));

	g_EntityFuncs.SetOrigin(pCustomGrenade.self, vecStart);
	g_EntityFuncs.SetModel(pCustomGrenade.self, sModel);
	g_EntityFuncs.DispatchSpawn(pCustomGrenade.self.edict());

	pCustomGrenade.pev.velocity = vecVelocity;
	pCustomGrenade.pev.angles = Math.VecToAngles(pCustomGrenade.pev.velocity);
	@pCustomGrenade.pev.owner = pevOwner.pContainingEntity;

	pCustomGrenade.pev.dmg = flDmg;
	pCustomGrenade.pev.sequence = Math.RandomLong(3, 6);

	pCustomGrenade.SetTouch(TouchFunction(pCustomGrenade.BounceTouch));
	pCustomGrenade.SetThink(ThinkFunction(pCustomGrenade.TumbleThink));
	pCustomGrenade.pev.nextthink = g_Engine.time + 0.1f;
	pCustomGrenade.pev.dmgtime = g_Engine.time + flTime;

	return pCustomGrenade;
}

enum eGrenadeAnimations {
	kIdling = 0,
	kPullingPin,
	kThrowing,
	kDeploying
};

class CCustomFrostGrenadeWpn : ScriptBasePlayerWeaponEntity {
	private CBasePlayer@ m_pPlayer {
		get const { return cast<CBasePlayer@>(self.m_hPlayer.GetEntity()); }
		set { self.m_hPlayer = EHandle(@value); }
	}
	private bool m_bInAttack, m_bThrown;
	private float m_fAttackStart, m_flStartThrow;
	private int GetBodygroup() {
		return 0;
	}
    private int m_iMode = 0;
    protected string m_lpszWorldModel;
    protected string m_lpszPlayerModel;
    protected string m_lpszViewModel;
    protected string m_lpszAccordingNade;
    protected int m_iPosition;
    protected array<EHandle> m_rghGrenades;
    
    CCustomFrostGrenadeWpn() {
        m_lpszWorldModel = "models/zombie_plague/cs/w_flashbang.mdl";
        m_lpszViewModel = "models/zombie_plague/v_grenade_frost_lefthanded.mdl";
        m_lpszPlayerModel = "models/zombie_plague/cs/p_flashbang.mdl";
        m_lpszAccordingNade = "zpc_frostnade";
        m_iPosition = 11;
        m_rghGrenades.resize(0);
    }
    
    void Spawn() {
		Precache();

		self.pev.dmg = 150;
        g_EntityFuncs.SetModel(self, self.GetW_Model(m_lpszWorldModel));
		self.pev.body = 1;
		BaseClass.Spawn();
		self.pev.scale = 1;
	}

	void Precache() {
		self.PrecacheCustomModels();
		g_Game.PrecacheOther(m_lpszAccordingNade);
		g_Game.PrecacheModel(m_lpszPlayerModel);
		g_Game.PrecacheModel(m_lpszViewModel);
		g_Game.PrecacheModel(m_lpszWorldModel);
        
        g_Game.PrecacheGeneric("sound/zombie_plague/cs/grenade/pin.wav");
        g_SoundSystem.PrecacheSound("zombie_plague/cs/grenade/pin.wav");
        
        g_Game.PrecacheGeneric("sprites/zombie_plague/weapons/weapon_frostgrenade.txt");
	}

	bool GetItemInfo(ItemInfo& out _Info) {
		_Info.iMaxAmmo1 = 10;
		_Info.iMaxAmmo2 = -1;
		_Info.iMaxClip = WEAPON_NOCLIP;
		_Info.iSlot = 3;
		_Info.iPosition = m_iPosition;
		_Info.iId = g_ItemRegistry.GetIdForName(self.pev.classname);
		_Info.iFlags = ITEM_FLAG_SELECTONEMPTY | ITEM_FLAG_EXHAUSTIBLE;
		_Info.iWeight = 5;

		return true;
	}

	bool AddToPlayer(CBasePlayer@ _Player) {
        if (!BaseClass.AddToPlayer(_Player))
            return false;

        NetworkMessage weapon(MSG_ONE, NetworkMessages::WeapPickup, _Player.edict());
            weapon.WriteShort(g_ItemRegistry.GetIdForName(self.pev.classname));
        weapon.End();
        
        return true;
	}

	// Better ammo extraction --- Anggara_nothing
	bool CanHaveDuplicates() {
		return true;
	}
    
    void DestroyThink() {
		SetThink(null);
		self.DestroyItem();
	}

	private int m_iAmmoSave;
	bool Deploy() {
		m_iAmmoSave = 0; // Zero out the ammo save
        self.DefaultDeploy(self.GetV_Model(m_lpszViewModel), self.GetP_Model(m_lpszPlayerModel), kDeploying, "gren", 0, GetBodygroup());
        self.m_flTimeWeaponIdle = self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = self.m_flNextTertiaryAttack = g_Engine.time + (20.f / 30.f);
        return true;
	}

	bool CanHolster() {
		if (m_fAttackStart != 0)
			return false;

		return true;
	}
    
    bool IsUseable() {
        return true;
    }

	bool CanDeploy() {
		if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) == 0 && m_iMode != 5)
			return false;

		return true;
	}

	private CBasePlayerItem@ DropItem() {
		m_iAmmoSave = m_pPlayer.AmmoInventory(self.m_iPrimaryAmmoType); //Save the player's ammo pool in case it has any in DropItem

		return self;
	}

	void Holster(int skipLocal = 0) {
		m_bThrown = false;
		m_bInAttack = false;
		m_fAttackStart = 0;
		m_flStartThrow = 0;

		self.m_fInReload = false;
		SetThink(null);

		m_pPlayer.pev.fuser4 = 0;

		if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) > 0) {
			m_iAmmoSave = m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType);
		}

		if (m_iAmmoSave <= 0 && m_iMode != 5 /* Satchel charge */) {
			SetThink(ThinkFunction(DestroyThink));
			self.pev.nextthink = g_Engine.time + 0.1f;
		}

		BaseClass.Holster(skipLocal);
	}

	void PrimaryAttack() {
		if( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0  )
			return;

		if( m_fAttackStart < 0 || m_fAttackStart > 0 )
			return;

		self.m_flNextPrimaryAttack = g_Engine.time + (40.0/41.0);
		self.SendWeaponAnim( kPullingPin, 0, GetBodygroup() );

		m_bInAttack = true;
		m_fAttackStart = g_Engine.time + (40.0/41.0);

		self.m_flTimeWeaponIdle = g_Engine.time + (40.0/41.0) + (23.0/30.0);
	}
    
    string ModeToString(int _Mode) {
        switch (_Mode) {
            case 0:
                return "Normal";
            case 1:
                return "Proximity";
            case 2:
                return "Impact";
            case 3:
                return "Trip laser";
            case 4:
                return "Motion sensor";
            case 5:
                return "Satchel charge";
            case 6:
                return "Homing";
        }
        
        return "Normal";
    }
    
    void SecondaryAttack() {
        if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) == 0 && m_iMode == 5) return;
    
        m_iMode++;
        
        if (m_iMode > 6)
            m_iMode = 0;
        
        g_PlayerFuncs.ClientPrint(m_pPlayer, HUD_PRINTCENTER, "Mode: " + ModeToString(m_iMode) + "\nUse tertiary attack button to explode\n     satchel charges");
        
        self.m_flNextSecondaryAttack = g_Engine.time + 0.15f;
    }

	void LaunchThink() {
		//g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_VOICE, SHOOT_S, VOL_NORM, ATTN_NORM, 0, PITCH_NORM );
		Vector angThrow = m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle;

		if ( angThrow.x < 0 )
			angThrow.x = -10 + angThrow.x * ( (90 - 10) / 90.0 );
		else
			angThrow.x = -10 + angThrow.x * ( (90 + 10) / 90.0 );

		float flVel = (90.0f - angThrow.x) * 6;

		if ( flVel > 750.0f )
			flVel = 750.0f;

		Math.MakeVectors( angThrow );

		Vector vecSrc = m_pPlayer.pev.origin + m_pPlayer.pev.view_ofs + g_Engine.v_forward * 16;
		Vector vecThrow = g_Engine.v_forward * flVel + m_pPlayer.pev.velocity;

		CCustomFrostGrenade@ pGrenade2 = ZM_UTIL_ShootFrostGrenade(m_pPlayer.pev, vecSrc, vecThrow, 1.5, 150, m_lpszWorldModel, m_lpszAccordingNade, m_iMode);
        m_rghGrenades.insertLast(EHandle(pGrenade2.self));

		m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) - 1 );
		m_fAttackStart = 0;
	}
    
    void TertiaryAttack() {
        for (uint idx = 0; idx < m_rghGrenades.length(); idx++) {
            EHandle hGrenade = m_rghGrenades[idx];
            if (!hGrenade.IsValid())
                continue;
            CBaseEntity@ pEntity = hGrenade.GetEntity();
            CCustomFrostGrenade@ pGrenade = cast<CCustomFrostGrenade@>(CastToScriptClass(pEntity));
            pGrenade.SatchelDetonate();
			SetThink(ThinkFunction(DestroyThink));
			self.pev.nextthink = g_Engine.time + 0.1f;
        }
    }

	void ItemPreFrame()
	{
		if( m_fAttackStart == 0 && m_bThrown == true && m_bInAttack == false && self.m_flTimeWeaponIdle - 0.1 < g_Engine.time )
		{
			if( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) == 0 )
			{
				self.Holster();
			}
			else
			{
				self.Deploy();
				m_bThrown = false;
				m_bInAttack = false;
				m_fAttackStart = 0;
				m_flStartThrow = 0;
			}
		}

		if( !m_bInAttack || (m_pPlayer.pev.button & (IN_ATTACK | IN_ATTACK2 | IN_ALT1) != 0) || g_Engine.time < m_fAttackStart )
			return;

		self.m_flTimeWeaponIdle = self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = self.m_flNextTertiaryAttack = g_Engine.time + (22.0/30.0);
		self.SendWeaponAnim(kThrowing, 0, GetBodygroup() );
		m_bThrown = true;
		m_bInAttack = false;
		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

		SetThink( ThinkFunction( this.LaunchThink ) );
		self.pev.nextthink = g_Engine.time + 0.05f;

		BaseClass.ItemPreFrame();
	}

	void WeaponIdle()
	{
		if( self.m_flTimeWeaponIdle > g_Engine.time )
			return;

		self.SendWeaponAnim(kIdling, 0, GetBodygroup() );
		self.m_flTimeWeaponIdle = g_Engine.time + g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed, 5, 7 );
	}
}

class CCustomFireGrenadeWpn : ScriptBasePlayerWeaponEntity {
	private CBasePlayer@ m_pPlayer {
		get const { return cast<CBasePlayer@>(self.m_hPlayer.GetEntity()); }
		set { self.m_hPlayer = EHandle(@value); }
	}
	private bool m_bInAttack, m_bThrown;
	private float m_fAttackStart, m_flStartThrow;
	private int GetBodygroup() {
		return 0;
	}
    private int m_iMode = 0;
    protected string m_lpszWorldModel;
    protected string m_lpszPlayerModel;
    protected string m_lpszViewModel;
    protected string m_lpszAccordingNade;
    protected int m_iPosition;
    protected array<EHandle> m_rghGrenades;
    
    CCustomFireGrenadeWpn() {
        m_lpszWorldModel = "models/zombie_plague/cs/w_hegrenade.mdl";
        m_lpszViewModel = "models/zombie_plague/v_grenade_fire_lefthanded.mdl";
        m_lpszPlayerModel = "models/zombie_plague/cs/p_hegrenade.mdl";
        m_lpszAccordingNade = "zpc_firenade";
        m_iPosition = 10;
        m_rghGrenades.resize(0);
    }
    
    void Spawn() {
		Precache();

		self.pev.dmg = 150;
        g_EntityFuncs.SetModel(self, self.GetW_Model(m_lpszWorldModel));
		self.pev.body = 1;
		BaseClass.Spawn();
		self.pev.scale = 1;
	}

	void Precache() {
		self.PrecacheCustomModels();
		g_Game.PrecacheOther(m_lpszAccordingNade);
		g_Game.PrecacheModel(m_lpszPlayerModel);
		g_Game.PrecacheModel(m_lpszViewModel);
		g_Game.PrecacheModel(m_lpszWorldModel);
        
        g_Game.PrecacheGeneric("sound/zombie_plague/cs/grenade/pin.wav");
        g_SoundSystem.PrecacheSound("zombie_plague/cs/grenade/pin.wav");
        
        g_Game.PrecacheGeneric("sprites/zombie_plague/weapons/weapon_firegrenade.txt");
	}
    
    bool GetItemInfo(ItemInfo& out _Info) {
		_Info.iMaxAmmo1 = 10;
		_Info.iMaxAmmo2 = -1;
		_Info.iMaxClip = WEAPON_NOCLIP;
		_Info.iSlot = 3;
		_Info.iPosition = m_iPosition;
		_Info.iId = g_ItemRegistry.GetIdForName(self.pev.classname);
		_Info.iFlags = ITEM_FLAG_SELECTONEMPTY | ITEM_FLAG_EXHAUSTIBLE;
		_Info.iWeight = 5;

		return true;
	}

	bool AddToPlayer(CBasePlayer@ _Player) {
        if (!BaseClass.AddToPlayer(_Player))
            return false;

        NetworkMessage weapon(MSG_ONE, NetworkMessages::WeapPickup, _Player.edict());
            weapon.WriteShort(g_ItemRegistry.GetIdForName(self.pev.classname));
        weapon.End();
        
        return true;
	}

	// Better ammo extraction --- Anggara_nothing
	bool CanHaveDuplicates() {
		return true;
	}
    
    void DestroyThink() {
		SetThink(null);
		self.DestroyItem();
	}

	private int m_iAmmoSave;
	bool Deploy() {
		m_iAmmoSave = 0; // Zero out the ammo save
        self.DefaultDeploy(self.GetV_Model(m_lpszViewModel), self.GetP_Model(m_lpszPlayerModel), kDeploying, "gren", 0, GetBodygroup());
        self.m_flTimeWeaponIdle = self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = self.m_flNextTertiaryAttack = g_Engine.time + (20.f / 30.f);
        return true;
	}
    
	bool CanHolster() {
		if (m_fAttackStart != 0)
			return false;

		return true;
	}

	bool IsUseable() {
        return true;
    }

	bool CanDeploy() {
		if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) == 0 && m_iMode != 5)
			return false;

		return true;
	}

	private CBasePlayerItem@ DropItem() {
		m_iAmmoSave = m_pPlayer.AmmoInventory(self.m_iPrimaryAmmoType); //Save the player's ammo pool in case it has any in DropItem

		return self;
	}

	void Holster(int skipLocal = 0) {
		m_bThrown = false;
		m_bInAttack = false;
		m_fAttackStart = 0;
		m_flStartThrow = 0;

		self.m_fInReload = false;
		SetThink(null);

		m_pPlayer.pev.fuser4 = 0;

		if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) > 0) {
			m_iAmmoSave = m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType);
		}

		if (m_iAmmoSave <= 0 && m_iMode != 5 /* Satchel charge */) {
			SetThink(ThinkFunction(DestroyThink));
			self.pev.nextthink = g_Engine.time + 0.1f;
		}

		BaseClass.Holster(skipLocal);
	}

	void PrimaryAttack() {
		if( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0  )
			return;

		if( m_fAttackStart < 0 || m_fAttackStart > 0 )
			return;

		self.m_flNextPrimaryAttack = g_Engine.time + (40.0/41.0);
		self.SendWeaponAnim( kPullingPin, 0, GetBodygroup() );

		m_bInAttack = true;
		m_fAttackStart = g_Engine.time + (40.0/41.0);

		self.m_flTimeWeaponIdle = g_Engine.time + (40.0/41.0) + (23.0/30.0);
	}
    
    string ModeToString(int _Mode) {
        switch (_Mode) {
            case 0:
                return "Normal";
            case 1:
                return "Proximity";
            case 2:
                return "Impact";
            case 3:
                return "Trip laser";
            case 4:
                return "Motion sensor";
            case 5:
                return "Satchel charge";
            case 6:
                return "Homing";
        }
        
        return "Normal";
    }
    
    void SecondaryAttack() {
        if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) == 0 && m_iMode == 5) return;
        
        m_iMode++;
        
        if (m_iMode > 6)
            m_iMode = 0;
        
        g_PlayerFuncs.ClientPrint(m_pPlayer, HUD_PRINTCENTER, "Mode: " + ModeToString(m_iMode) + "\nUse tertiary attack button to explode\n     satchel charges");
        
        self.m_flNextSecondaryAttack = g_Engine.time + 0.15f;
    }

    void TertiaryAttack() {
        for (uint idx = 0; idx < m_rghGrenades.length(); idx++) {
            EHandle hGrenade = m_rghGrenades[idx];
            if (!hGrenade.IsValid())
                continue;
            CBaseEntity@ pEntity = hGrenade.GetEntity();
            CCustomFireGrenade@ pGrenade = cast<CCustomFireGrenade@>(CastToScriptClass(pEntity));
            pGrenade.SatchelDetonate();
			SetThink(ThinkFunction(DestroyThink));
			self.pev.nextthink = g_Engine.time + 0.1f;
        }
    }

	void LaunchThink() {
		//g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_VOICE, SHOOT_S, VOL_NORM, ATTN_NORM, 0, PITCH_NORM );
		Vector angThrow = m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle;

		if ( angThrow.x < 0 )
			angThrow.x = -10 + angThrow.x * ( (90 - 10) / 90.0 );
		else
			angThrow.x = -10 + angThrow.x * ( (90 + 10) / 90.0 );

		float flVel = (90.0f - angThrow.x) * 6;

		if ( flVel > 750.0f )
			flVel = 750.0f;

		Math.MakeVectors( angThrow );

		Vector vecSrc = m_pPlayer.pev.origin + m_pPlayer.pev.view_ofs + g_Engine.v_forward * 16;
		Vector vecThrow = g_Engine.v_forward * flVel + m_pPlayer.pev.velocity;

		CCustomFireGrenade@ pGrenade2 = ZM_UTIL_ShootFireGrenade(m_pPlayer.pev, vecSrc, vecThrow, 1.5, 150, m_lpszWorldModel, m_lpszAccordingNade, m_iMode);
        m_rghGrenades.insertLast(EHandle(pGrenade2.self));

		m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) - 1 );
		m_fAttackStart = 0;
	}

	void ItemPreFrame()
	{
		if( m_fAttackStart == 0 && m_bThrown == true && m_bInAttack == false && self.m_flTimeWeaponIdle - 0.1 < g_Engine.time )
		{
			if( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) == 0 )
			{
				self.Holster();
			}
			else
			{
				self.Deploy();
				m_bThrown = false;
				m_bInAttack = false;
				m_fAttackStart = 0;
				m_flStartThrow = 0;
			}
		}

		if( !m_bInAttack || (m_pPlayer.pev.button & (IN_ATTACK | IN_ATTACK2 | IN_ALT1) != 0) || g_Engine.time < m_fAttackStart )
			return;

		self.m_flTimeWeaponIdle = self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = self.m_flNextTertiaryAttack = g_Engine.time + (22.0/30.0);
		self.SendWeaponAnim(kThrowing, 0, GetBodygroup() );
		m_bThrown = true;
		m_bInAttack = false;
		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

		SetThink( ThinkFunction( this.LaunchThink ) );
		self.pev.nextthink = g_Engine.time + 0.05f;

		BaseClass.ItemPreFrame();
	}

	void WeaponIdle()
	{
		if( self.m_flTimeWeaponIdle > g_Engine.time )
			return;

		self.SendWeaponAnim(kIdling, 0, GetBodygroup() );
		self.m_flTimeWeaponIdle = g_Engine.time + g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed, 5, 7 );
	}
}

class CZombieInfectionGrenadeWpn : ScriptBasePlayerWeaponEntity {
	private CBasePlayer@ m_pPlayer {
		get const { return cast<CBasePlayer@>(self.m_hPlayer.GetEntity()); }
		set { self.m_hPlayer = EHandle(@value); }
	}
	private bool m_bInAttack, m_bThrown;
	private float m_fAttackStart, m_flStartThrow;
	private int GetBodygroup() {
		return 0;
	}
    private int m_iMode = 0;
    protected string m_lpszWorldModel;
    protected string m_lpszPlayerModel;
    protected string m_lpszViewModel;
    protected string m_lpszAccordingNade;
    protected int m_iPosition;
    protected array<EHandle> m_rghGrenades;
    
    CZombieInfectionGrenadeWpn() {
        m_lpszWorldModel = "models/zombie_plague/cs/w_hegrenade.mdl";
        m_lpszViewModel = "models/zombie_plague/v_grenade_fire_lefthanded.mdl";
        m_lpszPlayerModel = "models/zombie_plague/cs/p_hegrenade.mdl";
        m_lpszAccordingNade = "zpc_infectiongrenade";
        m_iPosition = 13;
        m_rghGrenades.resize(0);
    }
    
    void Spawn() {
		Precache();

		self.pev.dmg = 150;
        g_EntityFuncs.SetModel(self, self.GetW_Model(m_lpszWorldModel));
		self.pev.body = 1;
		BaseClass.Spawn();
		self.pev.scale = 1;
	}

	void Precache() {
		self.PrecacheCustomModels();
		g_Game.PrecacheOther(m_lpszAccordingNade);
		g_Game.PrecacheModel(m_lpszPlayerModel);
		g_Game.PrecacheModel(m_lpszViewModel);
		g_Game.PrecacheModel(m_lpszWorldModel);
        
        g_Game.PrecacheGeneric("sound/zombie_plague/cs/grenade/pin.wav");
        g_SoundSystem.PrecacheSound("zombie_plague/cs/grenade/pin.wav");
        
        g_Game.PrecacheGeneric("sprites/zombie_plague/weapons/weapon_infectgrenade.txt");
	}
    
    bool GetItemInfo(ItemInfo& out _Info) {
		_Info.iMaxAmmo1 = 10;
		_Info.iMaxAmmo2 = -1;
		_Info.iMaxClip = WEAPON_NOCLIP;
		_Info.iSlot = 3;
		_Info.iPosition = m_iPosition;
		_Info.iId = g_ItemRegistry.GetIdForName(self.pev.classname);
		_Info.iFlags = ITEM_FLAG_SELECTONEMPTY | ITEM_FLAG_EXHAUSTIBLE;
		_Info.iWeight = 5;

		return true;
	}

	bool AddToPlayer(CBasePlayer@ _Player) {
        if (!BaseClass.AddToPlayer(_Player))
            return false;

        NetworkMessage weapon(MSG_ONE, NetworkMessages::WeapPickup, _Player.edict());
            weapon.WriteShort(g_ItemRegistry.GetIdForName(self.pev.classname));
        weapon.End();
        
        return true;
	}

	// Better ammo extraction --- Anggara_nothing
	bool CanHaveDuplicates() {
		return true;
	}
    
    void DestroyThink() {
		SetThink(null);
		self.DestroyItem();
	}

	private int m_iAmmoSave;
	bool Deploy() {
		m_iAmmoSave = 0; // Zero out the ammo save
        self.DefaultDeploy(self.GetV_Model(m_lpszViewModel), self.GetP_Model(m_lpszPlayerModel), kDeploying, "gren", 0, GetBodygroup());
        self.m_flTimeWeaponIdle = self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = self.m_flNextTertiaryAttack = g_Engine.time + (20.f / 30.f);
        return true;
	}
    
	bool CanHolster() {
		if (m_fAttackStart != 0)
			return false;

		return true;
	}

	bool IsUseable() {
        return true;
    }

	bool CanDeploy() {
		if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) == 0 && m_iMode != 5)
			return false;

		return true;
	}

	private CBasePlayerItem@ DropItem() {
		m_iAmmoSave = m_pPlayer.AmmoInventory(self.m_iPrimaryAmmoType); //Save the player's ammo pool in case it has any in DropItem

		return self;
	}

	void Holster(int skipLocal = 0) {
		m_bThrown = false;
		m_bInAttack = false;
		m_fAttackStart = 0;
		m_flStartThrow = 0;

		self.m_fInReload = false;
		SetThink(null);

		m_pPlayer.pev.fuser4 = 0;

		if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) > 0) {
			m_iAmmoSave = m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType);
		}

		if (m_iAmmoSave <= 0 && m_iMode != 5 /* Satchel charge */) {
			SetThink(ThinkFunction(DestroyThink));
			self.pev.nextthink = g_Engine.time + 0.1f;
		}

		BaseClass.Holster(skipLocal);
	}

	void PrimaryAttack() {
		if( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0  )
			return;

		if( m_fAttackStart < 0 || m_fAttackStart > 0 )
			return;

		self.m_flNextPrimaryAttack = g_Engine.time + (40.0/41.0);
		self.SendWeaponAnim( kPullingPin, 0, GetBodygroup() );

		m_bInAttack = true;
		m_fAttackStart = g_Engine.time + (40.0/41.0);

		self.m_flTimeWeaponIdle = g_Engine.time + (40.0/41.0) + (23.0/30.0);
	}
    
    string ModeToString(int _Mode) {
        switch (_Mode) {
            case 0:
                return "Normal";
            case 1:
                return "Proximity";
            case 2:
                return "Impact";
            case 3:
                return "Trip laser";
            case 4:
                return "Motion sensor";
            case 5:
                return "Satchel charge";
            case 6:
                return "Homing";
        }
        
        return "Normal";
    }
    
    void SecondaryAttack() {
        if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) == 0 && m_iMode == 5) return;
        
        m_iMode++;
        
        if (m_iMode > 6)
            m_iMode = 0;
        
        g_PlayerFuncs.ClientPrint(m_pPlayer, HUD_PRINTCENTER, "Mode: " + ModeToString(m_iMode) + "\nUse tertiary attack button to explode\n     satchel charges");
        
        self.m_flNextSecondaryAttack = g_Engine.time + 0.15f;
    }

    void TertiaryAttack() {
        for (uint idx = 0; idx < m_rghGrenades.length(); idx++) {
            EHandle hGrenade = m_rghGrenades[idx];
            if (!hGrenade.IsValid())
                continue;
            CBaseEntity@ pEntity = hGrenade.GetEntity();
            CCustomFireGrenade@ pGrenade = cast<CCustomFireGrenade@>(CastToScriptClass(pEntity));
            pGrenade.SatchelDetonate();
			SetThink(ThinkFunction(DestroyThink));
			self.pev.nextthink = g_Engine.time + 0.1f;
        }
    }

	void LaunchThink() {
		//g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_VOICE, SHOOT_S, VOL_NORM, ATTN_NORM, 0, PITCH_NORM );
		Vector angThrow = m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle;

		if ( angThrow.x < 0 )
			angThrow.x = -10 + angThrow.x * ( (90 - 10) / 90.0 );
		else
			angThrow.x = -10 + angThrow.x * ( (90 + 10) / 90.0 );

		float flVel = (90.0f - angThrow.x) * 6;

		if ( flVel > 750.0f )
			flVel = 750.0f;

		Math.MakeVectors( angThrow );

		Vector vecSrc = m_pPlayer.pev.origin + m_pPlayer.pev.view_ofs + g_Engine.v_forward * 16;
		Vector vecThrow = g_Engine.v_forward * flVel + m_pPlayer.pev.velocity;

		CZombieInfectionGrenade@ pGrenade2 = ZM_UTIL_ShootZombieInfectionGrenade(m_pPlayer.pev, vecSrc, vecThrow, 1.5, 150, m_lpszWorldModel, m_lpszAccordingNade, m_iMode);
        m_rghGrenades.insertLast(EHandle(pGrenade2.self));

		m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) - 1 );
		m_fAttackStart = 0;
	}

	void ItemPreFrame()
	{
		if( m_fAttackStart == 0 && m_bThrown == true && m_bInAttack == false && self.m_flTimeWeaponIdle - 0.1 < g_Engine.time )
		{
			if( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) == 0 )
			{
				self.Holster();
			}
			else
			{
				self.Deploy();
				m_bThrown = false;
				m_bInAttack = false;
				m_fAttackStart = 0;
				m_flStartThrow = 0;
			}
		}

		if( !m_bInAttack || (m_pPlayer.pev.button & (IN_ATTACK | IN_ATTACK2 | IN_ALT1) != 0) || g_Engine.time < m_fAttackStart )
			return;

		self.m_flTimeWeaponIdle = self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = self.m_flNextTertiaryAttack = g_Engine.time + (22.0/30.0);
		self.SendWeaponAnim(kThrowing, 0, GetBodygroup() );
		m_bThrown = true;
		m_bInAttack = false;
		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

		SetThink( ThinkFunction( this.LaunchThink ) );
		self.pev.nextthink = g_Engine.time + 0.05f;

		BaseClass.ItemPreFrame();
	}

	void WeaponIdle()
	{
		if( self.m_flTimeWeaponIdle > g_Engine.time )
			return;

		self.SendWeaponAnim(kIdling, 0, GetBodygroup() );
		self.m_flTimeWeaponIdle = g_Engine.time + g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed, 5, 7 );
	}
}

class CZombieJumpGrenadeWpn : ScriptBasePlayerWeaponEntity {
	private CBasePlayer@ m_pPlayer {
		get const { return cast<CBasePlayer@>(self.m_hPlayer.GetEntity()); }
		set { self.m_hPlayer = EHandle(@value); }
	}
	private bool m_bInAttack, m_bThrown;
	private float m_fAttackStart, m_flStartThrow;
	private int GetBodygroup() {
		return 0;
	}
    protected string m_lpszWorldModel;
    protected string m_lpszPlayerModel;
    protected string m_lpszViewModel;
    protected string m_lpszAccordingNade;
    protected int m_iPosition;
    
    CZombieJumpGrenadeWpn() {
        m_lpszWorldModel = "models/zombie_plague/w_zombibomb.mdl";
        m_lpszViewModel = "models/zombie_plague/v_zombibomb_lefthanded.mdl";
        m_lpszPlayerModel = "models/zombie_plague/p_zombibomb.mdl";
        m_lpszAccordingNade = "zpc_jumpgrenade";
        m_iPosition = 14;
    }
    
    void Spawn() {
		Precache();

		self.pev.dmg = 150;
        g_EntityFuncs.SetModel(self, self.GetW_Model(m_lpszWorldModel));
		self.pev.body = 1;
		BaseClass.Spawn();
		self.pev.scale = 1;
	}

	void Precache() {
		self.PrecacheCustomModels();
		g_Game.PrecacheOther(m_lpszAccordingNade);
		g_Game.PrecacheModel(m_lpszPlayerModel);
		g_Game.PrecacheModel(m_lpszViewModel);
		g_Game.PrecacheModel(m_lpszWorldModel);
        
        g_Game.PrecacheGeneric("sprites/zombie_plague/weapons/weapon_jumpgrenade.txt");
	}
    
    bool GetItemInfo(ItemInfo& out _Info) {
		_Info.iMaxAmmo1 = 10;
		_Info.iMaxAmmo2 = -1;
		_Info.iMaxClip = WEAPON_NOCLIP;
		_Info.iSlot = 3;
		_Info.iPosition = m_iPosition;
		_Info.iId = g_ItemRegistry.GetIdForName(self.pev.classname);
		_Info.iFlags = ITEM_FLAG_SELECTONEMPTY | ITEM_FLAG_EXHAUSTIBLE;
		_Info.iWeight = 5;

		return true;
	}

	bool AddToPlayer(CBasePlayer@ _Player) {
        if (!BaseClass.AddToPlayer(_Player))
            return false;

        NetworkMessage weapon(MSG_ONE, NetworkMessages::WeapPickup, _Player.edict());
            weapon.WriteShort(g_ItemRegistry.GetIdForName(self.pev.classname));
        weapon.End();
        
        return true;
	}

	// Better ammo extraction --- Anggara_nothing
	bool CanHaveDuplicates() {
		return true;
	}
    
    void DestroyThink() {
		SetThink(null);
		self.DestroyItem();
	}

	private int m_iAmmoSave;
	bool Deploy() {
		m_iAmmoSave = 0; // Zero out the ammo save
        self.DefaultDeploy(self.GetV_Model(m_lpszViewModel), self.GetP_Model(m_lpszPlayerModel), kDeploying, "gren", 0, GetBodygroup());
        self.m_flTimeWeaponIdle = self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = self.m_flNextTertiaryAttack = g_Engine.time + (20.f / 30.f);
        return true;
	}
    
	bool CanHolster() {
		if (m_fAttackStart != 0)
			return false;

		return true;
	}

	bool IsUseable() {
        return true;
    }

	bool CanDeploy() {
		if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) == 0)
			return false;

		return true;
	}

	private CBasePlayerItem@ DropItem() {
		m_iAmmoSave = m_pPlayer.AmmoInventory(self.m_iPrimaryAmmoType); //Save the player's ammo pool in case it has any in DropItem

		return self;
	}

	void Holster(int skipLocal = 0) {
		m_bThrown = false;
		m_bInAttack = false;
		m_fAttackStart = 0;
		m_flStartThrow = 0;

		self.m_fInReload = false;
		SetThink(null);

		m_pPlayer.pev.fuser4 = 0;

		if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) > 0) {
			m_iAmmoSave = m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType);
		}

		if (m_iAmmoSave <= 0) {
			SetThink(ThinkFunction(DestroyThink));
			self.pev.nextthink = g_Engine.time + 0.1f;
		}

		BaseClass.Holster(skipLocal);
	}

	void PrimaryAttack() {
		if( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0  )
			return;

		if( m_fAttackStart < 0 || m_fAttackStart > 0 )
			return;

		self.m_flNextPrimaryAttack = g_Engine.time + (40.0/41.0);
		self.SendWeaponAnim( kPullingPin, 0, GetBodygroup() );

		m_bInAttack = true;
		m_fAttackStart = g_Engine.time + (40.0/41.0);

		self.m_flTimeWeaponIdle = g_Engine.time + (40.0/41.0) + (23.0/30.0);
	}

	void LaunchThink() {
		//g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_VOICE, SHOOT_S, VOL_NORM, ATTN_NORM, 0, PITCH_NORM );
		Vector angThrow = m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle;

		if ( angThrow.x < 0 )
			angThrow.x = -10 + angThrow.x * ( (90 - 10) / 90.0 );
		else
			angThrow.x = -10 + angThrow.x * ( (90 + 10) / 90.0 );

		float flVel = (90.0f - angThrow.x) * 6;

		if ( flVel > 750.0f )
			flVel = 750.0f;

		Math.MakeVectors( angThrow );

		Vector vecSrc = m_pPlayer.pev.origin + m_pPlayer.pev.view_ofs + g_Engine.v_forward * 16;
		Vector vecThrow = g_Engine.v_forward * flVel + m_pPlayer.pev.velocity;

		CZombieJumpGrenade@ pGrenade2 = ZM_UTIL_ShootZombieJumpGrenade(m_pPlayer.pev, vecSrc, vecThrow, 1.5, 150, m_lpszWorldModel, m_lpszAccordingNade);

		m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) - 1 );
		m_fAttackStart = 0;
	}

	void ItemPreFrame()
	{
		if( m_fAttackStart == 0 && m_bThrown == true && m_bInAttack == false && self.m_flTimeWeaponIdle - 0.1 < g_Engine.time )
		{
			if( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) == 0 )
			{
				self.Holster();
			}
			else
			{
				self.Deploy();
				m_bThrown = false;
				m_bInAttack = false;
				m_fAttackStart = 0;
				m_flStartThrow = 0;
			}
		}

		if( !m_bInAttack || (m_pPlayer.pev.button & (IN_ATTACK | IN_ATTACK2 | IN_ALT1) != 0) || g_Engine.time < m_fAttackStart )
			return;

		self.m_flTimeWeaponIdle = self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = self.m_flNextTertiaryAttack = g_Engine.time + (22.0/30.0);
		self.SendWeaponAnim(kThrowing, 0, GetBodygroup() );
		m_bThrown = true;
		m_bInAttack = false;
		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

		SetThink( ThinkFunction( this.LaunchThink ) );
		self.pev.nextthink = g_Engine.time + 0.05f;

		BaseClass.ItemPreFrame();
	}

	void WeaponIdle()
	{
		if( self.m_flTimeWeaponIdle > g_Engine.time )
			return;

		self.SendWeaponAnim(kIdling, 0, GetBodygroup() );
		self.m_flTimeWeaponIdle = g_Engine.time + g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed, 5, 7 );
	}
}

class CCustomGrenadeWpn : ScriptBasePlayerWeaponEntity {
	private CBasePlayer@ m_pPlayer {
		get const { return cast<CBasePlayer@>(self.m_hPlayer.GetEntity()); }
		set { self.m_hPlayer = EHandle(@value); }
	}
	private bool m_bInAttack, m_bThrown;
	private float m_fAttackStart, m_flStartThrow;
	private int GetBodygroup() {
		return 0;
	}
    private int m_iMode = 0;
    protected string m_lpszWorldModel;
    protected string m_lpszPlayerModel;
    protected string m_lpszViewModel;
    protected string m_lpszAccordingNade;
    protected int m_iPosition;
    protected array<EHandle> m_rghGrenades;

    CCustomGrenadeWpn() {
        m_lpszWorldModel = "models/zombie_plague/cs/w_smokegrenade.mdl";
        m_lpszViewModel = "models/zombie_plague/v_grenade_flare_lefthanded.mdl";
        m_lpszPlayerModel = "models/zombie_plague/cs/p_smokegrenade.mdl";
        m_lpszAccordingNade = "zpc_smokenade";
        m_iPosition = 12;
        m_rghGrenades.resize(0);
    }

	void Spawn() {
		Precache();

		self.pev.dmg = 150;
        g_EntityFuncs.SetModel(self, self.GetW_Model(m_lpszWorldModel));
		self.pev.body = 1;
		BaseClass.Spawn();
		self.pev.scale = 1;
	}

	void Precache() {
		self.PrecacheCustomModels();
		g_Game.PrecacheOther(m_lpszAccordingNade);
		g_Game.PrecacheModel(m_lpszPlayerModel);
		g_Game.PrecacheModel(m_lpszViewModel);
		g_Game.PrecacheModel(m_lpszWorldModel);
        
        g_Game.PrecacheGeneric("sound/zombie_plague/cs/grenade/pin.wav");
        g_SoundSystem.PrecacheSound("zombie_plague/cs/grenade/pin.wav");
        
        g_Game.PrecacheGeneric("sprites/zombie_plague/weapons/weapon_flaregrenade.txt");
	}

	bool GetItemInfo(ItemInfo& out _Info) {
		_Info.iMaxAmmo1 = 10;
		_Info.iMaxAmmo2 = -1;
		_Info.iMaxClip = WEAPON_NOCLIP;
		_Info.iSlot = 3;
		_Info.iPosition = m_iPosition;
		_Info.iId = g_ItemRegistry.GetIdForName(self.pev.classname);
		_Info.iFlags = ITEM_FLAG_SELECTONEMPTY | ITEM_FLAG_EXHAUSTIBLE;
		_Info.iWeight = 5;

		return true;
	}

	bool AddToPlayer(CBasePlayer@ _Player) {
        if (!BaseClass.AddToPlayer(_Player))
            return false;

        NetworkMessage weapon(MSG_ONE, NetworkMessages::WeapPickup, _Player.edict());
            weapon.WriteShort(g_ItemRegistry.GetIdForName(self.pev.classname));
        weapon.End();
        
        return true;
	}

	// Better ammo extraction --- Anggara_nothing
	bool CanHaveDuplicates() {
		return true;
	}
    
    void DestroyThink() {
		SetThink(null);
		self.DestroyItem();
	}

	private int m_iAmmoSave;
	bool Deploy() {
		m_iAmmoSave = 0; // Zero out the ammo save
        self.DefaultDeploy(self.GetV_Model(m_lpszViewModel), self.GetP_Model(m_lpszPlayerModel), kDeploying, "gren", 0, GetBodygroup());
        self.m_flTimeWeaponIdle = self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = self.m_flNextTertiaryAttack = g_Engine.time + (20.f / 30.f);
        return true;
	}

		bool CanHolster() {
		if (m_fAttackStart != 0)
			return false;

		return true;
	}
    
    bool IsUseable() {
        return true;
    }

	bool CanDeploy() {
		if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) == 0 && m_iMode != 5)
			return false;

		return true;
	}

	private CBasePlayerItem@ DropItem() {
		m_iAmmoSave = m_pPlayer.AmmoInventory(self.m_iPrimaryAmmoType); //Save the player's ammo pool in case it has any in DropItem

		return self;
	}

	void Holster(int skipLocal = 0) {
		m_bThrown = false;
		m_bInAttack = false;
		m_fAttackStart = 0;
		m_flStartThrow = 0;

		self.m_fInReload = false;
		SetThink(null);

		m_pPlayer.pev.fuser4 = 0;

		if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) > 0) {
			m_iAmmoSave = m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType);
		}

		if (m_iAmmoSave <= 0 && m_iMode != 5 /* Satchel charge */) {
			SetThink(ThinkFunction(DestroyThink));
			self.pev.nextthink = g_Engine.time + 0.1f;
		}

		BaseClass.Holster(skipLocal);
	}

	void PrimaryAttack() {
		if( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0  )
			return;

		if( m_fAttackStart < 0 || m_fAttackStart > 0 )
			return;

		self.m_flNextPrimaryAttack = g_Engine.time + (40.0/41.0);
		self.SendWeaponAnim( kPullingPin, 0, GetBodygroup() );

		m_bInAttack = true;
		m_fAttackStart = g_Engine.time + (40.0/41.0);

		self.m_flTimeWeaponIdle = g_Engine.time + (40.0/41.0) + (23.0/30.0);
	}
    
    string ModeToString(int _Mode) {
        switch (_Mode) {
            case 0:
                return "Normal";
            case 1:
                return "Proximity";
            case 2:
                return "Impact";
            case 3:
                return "Trip laser";
            case 4:
                return "Motion sensor";
            case 5:
                return "Satchel charge";
            case 6:
                return "Homing";
        }
        
        return "Normal";
    }
    
    void SecondaryAttack() {
        if (m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) == 0 && m_iMode == 5) return;
    
        m_iMode++;
        
        if (m_iMode > 6)
            m_iMode = 0;
        
        g_PlayerFuncs.ClientPrint(m_pPlayer, HUD_PRINTCENTER, "Mode: " + ModeToString(m_iMode) + "\nUse tertiary attack button to explode\n     satchel charges");
        
        self.m_flNextSecondaryAttack = g_Engine.time + 0.15f;
    }

	void LaunchThink() {
		//g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_VOICE, SHOOT_S, VOL_NORM, ATTN_NORM, 0, PITCH_NORM );
		Vector angThrow = m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle;

		if ( angThrow.x < 0 )
			angThrow.x = -10 + angThrow.x * ( (90 - 10) / 90.0 );
		else
			angThrow.x = -10 + angThrow.x * ( (90 + 10) / 90.0 );

		float flVel = (90.0f - angThrow.x) * 6;

		if ( flVel > 750.0f )
			flVel = 750.0f;

		Math.MakeVectors( angThrow );

		Vector vecSrc = m_pPlayer.pev.origin + m_pPlayer.pev.view_ofs + g_Engine.v_forward * 16;
		Vector vecThrow = g_Engine.v_forward * flVel + m_pPlayer.pev.velocity;

		CCustomGrenade@ pGrenade2 = ZM_UTIL_ShootGrenade(m_pPlayer.pev, vecSrc, vecThrow, 1.5, 150, m_lpszWorldModel, m_lpszAccordingNade, m_iMode);
        m_rghGrenades.insertLast(EHandle(pGrenade2.self));

		m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) - 1 );
		m_fAttackStart = 0;
	}
        
    void TertiaryAttack() {
        for (uint idx = 0; idx < m_rghGrenades.length(); idx++) {
            EHandle hGrenade = m_rghGrenades[idx];
            if (!hGrenade.IsValid())
                continue;
            CBaseEntity@ pEntity = hGrenade.GetEntity();
            CCustomGrenade@ pGrenade = cast<CCustomGrenade@>(CastToScriptClass(pEntity));
            pGrenade.SatchelDetonate();
			SetThink(ThinkFunction(DestroyThink));
			self.pev.nextthink = g_Engine.time + 0.1f;
        }
    }

	void ItemPreFrame()
	{
		if( m_fAttackStart == 0 && m_bThrown == true && m_bInAttack == false && self.m_flTimeWeaponIdle - 0.1 < g_Engine.time )
		{
			if( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) == 0 )
			{
				self.Holster();
			}
			else
			{
				self.Deploy();
				m_bThrown = false;
				m_bInAttack = false;
				m_fAttackStart = 0;
				m_flStartThrow = 0;
			}
		}

		if( !m_bInAttack || (m_pPlayer.pev.button & (IN_ATTACK | IN_ATTACK2 | IN_ALT1) != 0) || g_Engine.time < m_fAttackStart )
			return;

		self.m_flTimeWeaponIdle = self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = self.m_flNextTertiaryAttack = g_Engine.time + (22.0/30.0);
		self.SendWeaponAnim(kThrowing, 0, GetBodygroup() );
		m_bThrown = true;
		m_bInAttack = false;
		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

		SetThink( ThinkFunction( this.LaunchThink ) );
		self.pev.nextthink = g_Engine.time + 0.05f;

		BaseClass.ItemPreFrame();
	}

	void WeaponIdle()
	{
		if( self.m_flTimeWeaponIdle > g_Engine.time )
			return;

		self.SendWeaponAnim(kIdling, 0, GetBodygroup() );
		self.m_flTimeWeaponIdle = g_Engine.time + g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed, 5, 7 );
	}
}

class CHumanClass {
    string m_lpszName;
    string m_lpszDescription;
    float m_flHealth;
    float m_flArmour;
    
    CHumanClass(const string& in _Name, const string& in _Description, float _Health, float _Armour) {
        m_lpszName = _Name;
        m_lpszDescription = _Description;
        m_flHealth = _Health;
        m_flArmour = _Armour;
    }
}

array<CHumanClass@> g_rglpHumanClasses;

CHumanClass@ ZM_UTIL_FindHumanClassByName(const string& in _Name) {
    for (uint idx = 0; idx < g_rglpHumanClasses.length(); idx++) {
        CHumanClass@ lpKlass = g_rglpHumanClasses[idx];
        if (lpKlass.m_lpszName == _Name) return @lpKlass;
    }

    return null;
}

funcdef void g_tZombieOnceHasInfectedSomebodyCallBack(EHandle _Zombie, EHandle _Victim);

class CZombieClass {
    string m_lpszPlayerModel;
    bool m_bCanBeSelectedViaMenu;
    string m_lpszDescription;
    string m_lpszName;
    float m_flHealth;
    float m_flGravity;
    float m_flMaxSpeed;
    float m_flKnockback;
    g_tZombieOnceHasInfectedSomebodyCallBack@ m_lpfnOnceHasInfectedSomebodyCB;
    
    CZombieClass(const string& in _Name, const string& in _Description, bool _bCanBeSelectedViaMenu, const string& in _PlayerModel, float _Health, float _Gravity, float _MaxSpeed, float _Knockback, g_tZombieOnceHasInfectedSomebodyCallBack@ _OnceHasInfectedSomebodyCB = null) {
        m_lpszName = _Name;
        m_lpszDescription = _Description;
        m_bCanBeSelectedViaMenu = _bCanBeSelectedViaMenu;
        m_lpszPlayerModel = _PlayerModel;
        m_flHealth = _Health;
        m_flGravity = _Gravity;
        m_flMaxSpeed = _MaxSpeed;
        m_flKnockback = _Knockback;
        @m_lpfnOnceHasInfectedSomebodyCB = _OnceHasInfectedSomebodyCB;
    }
}

array<CZombieClass@> g_rglpZombieClasses;

CZombieClass@ ZM_UTIL_FindZombieClassByName(const string& in _Name) {
    for (uint idx = 0; idx < g_rglpZombieClasses.length(); idx++) {
        CZombieClass@ lpKlass = g_rglpZombieClasses[idx];
        if (lpKlass.m_lpszName == _Name) return @lpKlass;
    }

    return null;
}

class CPlayerData {
    string m_lpszSteamID;
    bool m_bHasGotFirstWeapon;
    bool m_bHasGotSecondaryWeapon;
    string m_lpszBackupModel;
    CZombieClass@ m_lpZombieClass;
    CZombieClass@ m_lpBackupZombieClass;
    CHumanClass@ m_lpHumanClass;
    float m_flLastLongjumpTime;
    
    CPlayerData(const string& in _SteamID) {
        m_lpszSteamID = _SteamID;
        m_bHasGotFirstWeapon = false;
        m_bHasGotSecondaryWeapon = false;
        m_lpszBackupModel = "helmet";
        @m_lpZombieClass = g_rglpZombieClasses[0];
        @m_lpBackupZombieClass = null;
        @m_lpHumanClass = g_rglpHumanClasses[0];
        m_flLastLongjumpTime = 0.f;
    }
}

array<CPlayerData@> g_rglpPlayerDatas;
array<CPlayerData@> g_rglpFastPlayerDataAccessor;

CPlayerData@ ZM_UTIL_GetPlayerDataBySteamID(const string& in _SteamID) {
    if (g_rglpPlayerDatas.length() == 0) return null; //save some computing powerz
    
    for (uint idx = 0; idx < g_rglpPlayerDatas.length(); idx++) {
        CPlayerData@ pData = g_rglpPlayerDatas[idx];
        
        if (pData.m_lpszSteamID == _SteamID) return pData;
    }

    return null;
}

void ZM_UTIL_RemoveZombieBySteamID(const string& in _SteamID) {
    for (uint idx = 0; idx < g_ahZombies.length(); idx++) {
        EHandle hZombie = g_ahZombies[idx];
        if (!hZombie.IsValid()) {
            g_ahZombies.removeAt(idx);
            
            continue;
        }
        
        CBaseEntity@ pEntity = hZombie.GetEntity();
        if (_SteamID == g_EngineFuncs.GetPlayerAuthId(pEntity.edict())) {
            g_ahZombies.removeAt(idx);
            break;
        }
    }
}

string ZM_UTIL_CountdownNumberToString(int _Number) {
    switch (_Number) {
        case 10:
            return "ten";
        case 9:
            return "nine";
        case 8:
            return "eight";
        case 7:
            return "seven";
        case 6:
            return "six";
        case 5:
            return "five";
        case 4:
            return "four";
        case 3:
            return "three";
        case 2:
            return "two";
        case 1:
            return "one";
    }
    
    return "";
}

bool ZM_UTIL_IsPlayerZombie(const string& in _SteamID) {
    if (g_ahZombies.length() == 0) return false;

    for (uint idx = 0; idx < g_ahZombies.length(); idx++) {
        EHandle hZombie = g_ahZombies[idx];
        if (!hZombie.IsValid()) continue;
        if (g_EngineFuncs.GetPlayerAuthId(hZombie.GetEntity().edict()) == _SteamID) 
            return true;
    }
    
    return false;
}

bool ZM_UTIL_IsPlayerAHumanTank(const string& in _SteamID) {
    if (g_ahHumanTanks.length() == 0) return false;

    for (uint idx = 0; idx < g_ahHumanTanks.length(); idx++) {
        EHandle hHumanTank = g_ahHumanTanks[idx];
        if (!hHumanTank.IsValid()) continue;
        if (g_EngineFuncs.GetPlayerAuthId(hHumanTank.GetEntity().edict()) == _SteamID) 
            return true;
    }
    
    return false;
}

void ZM_UTIL_TurnPlayerIntoAZombie(CBasePlayer@ _Player) {
    int nPlayerIdx = _Player.entindex();
    if (!g_abIsNemesis[nPlayerIdx] && !g_abIsAssassin[nPlayerIdx])
        ZM_UTIL_PlayRandomInfectionSound(_Player.edict());
        
    string szSteamID = g_EngineFuncs.GetPlayerAuthId(_Player.edict());
    CPlayerData@ pData = ZM_UTIL_GetPlayerDataBySteamID(szSteamID);
    if (pData !is null) {
        _Player.pev.max_health = pData.m_lpZombieClass.m_flHealth;
        _Player.pev.health = pData.m_lpZombieClass.m_flHealth;
        _Player.pev.gravity = pData.m_lpZombieClass.m_flGravity / 800.f;
        _Player.pev.maxspeed = pData.m_lpZombieClass.m_flMaxSpeed;
    }
    _Player.SetClassification(17); //red team
    _Player.SendScoreInfo();
    g_rgflLastZombieSentenceTime[nPlayerIdx] = g_Engine.time + float(Math.RandomLong(5, 15));
    g_abZombies[nPlayerIdx] = true;
    g_abZombieTrickyNightVision[nPlayerIdx] = true;
    _Player.RemoveAllItems(false);
    if (g_abIsNemesis[nPlayerIdx]) {
        _Player.GiveNamedItem("weapon_executioner_axe", 0, 0);
    } else {
        _Player.GiveNamedItem("weapon_zombieknife", 0, 0);
    }
    if (g_bDefaultRound || g_bMultiInfectionMode || g_bSwarmRound) {
        _Player.GiveNamedItem("weapon_jumpgrenade", 0, 1);
            
        CBasePlayerItem@ pItem;
        CBasePlayerWeapon@ pWeapon;
        for (uint j = 0; j < 10; j++) {
            @pItem = _Player.m_rgpPlayerItems(j);
            while (pItem !is null) {
                @pWeapon = pItem.GetWeaponPtr();
                            
                if (pWeapon.GetClassname() == "weapon_jumpgrenade") {
                    int iPrimaryIdx = pWeapon.PrimaryAmmoIndex();
                    if (iPrimaryIdx != -1) {
                        _Player.m_rgAmmo(iPrimaryIdx, _Player.m_rgAmmo(iPrimaryIdx) + 1);
                    }
                }
                            
                @pItem = cast<CBasePlayerItem@>(pItem.m_hNextItem.GetEntity());
            }
        }
    }
}

void ZM_UTIL_SendSpeakSoundStuffTextMsg(const string& in _SoundName) {
    string strMsg = ";spk \"" + _SoundName + "\";\n";
    
    NetworkMessage msg(MSG_ALL, NetworkMessages::SVC_STUFFTEXT, null);
    msg.WriteString(strMsg);
    msg.End();
}

array<string> g_rglpszInfectionSounds = { "zombie_plague/zombie_infec1.wav", "zombie_plague/zombie_infec2.wav", "zombie_plague/zombie_infec3.wav" };
array<string> g_rglpszPainSounds = { "zombie_plague/zombie_pain1.wav", "zombie_plague/zombie_pain2.wav", "zombie_plague/zombie_pain3.wav", "zombie_plague/zombie_pain4.wav", "zombie_plague/zombie_pain5.wav" };
array<string> g_rglpszNemesisPainSounds = { "zombie_plague/nemesis_pain1.wav", "zombie_plague/nemesis_pain2.wav", "zombie_plague/nemesis_pain3.wav" };
array<string> g_rglpszDeathSounds = { "zombie_plague/zombie_die1.wav", "zombie_plague/zombie_die2.wav", "zombie_plague/zombie_die3.wav", "zombie_plague/zombie_die4.wav", "zombie_plague/zombie_die5.wav" };
array<string> g_rglpszZombiesWinSounds = { "zombie_plague/hl/ambience/the_horror1.wav", "zombie_plague/hl/ambience/the_horror3.wav", "zombie_plague/hl/ambience/the_horror4.wav" };
array<string> g_rglpszNihilanthQuotes = { "zombie_plague/hl/nihilanth/nil_alone.wav", "zombie_plague/hl/nihilanth/nil_now_die.wav", "zombie_plague/hl/nihilanth/nil_slaves.wav", "zombie_plague/hl/nihilanth/nil_thelast.wav", "zombie_plague/zombie_brains1.wav", "zombie_plague/zombie_brains2.wav" };
array<string> g_rglpszZombieBurnSounds = { "zombie_plague/zombie_burn3.wav" , "zombie_plague/zombie_burn4.wav" , "zombie_plague/zombie_burn5.wav" , "zombie_plague/zombie_burn6.wav" , "zombie_plague/zombie_burn7.wav" };
array<string> g_rglpszRoundStartSounds = { "zombie_plague/hl/ambience/the_horror2.wav", "zombie_plague/hl/scientist/c1a0_sci_catscream.wav" };
array<string> g_rglpszNemesisRoundStartSounds = { "zombie_plague/nemesis1.wav", "zombie_plague/nemesis2.wav" };
array<string> g_rglpszHumanTankRoundStartSounds = { "zombie_plague/survivor1.wav", "zombie_plague/survivor2.wav" };

void ZM_UTIL_PlayRandomBurnSound(edict_t@ _Edict) {
    g_SoundSystem.EmitSoundDyn(_Edict, CHAN_VOICE, g_rglpszZombieBurnSounds[Math.RandomLong(0, g_rglpszZombieBurnSounds.length() - 1)], 1.0f, ATTN_NORM, 0, PITCH_NORM);
}

void ZM_UTIL_PlayRandomNihilanthQuote(edict_t@ _Edict) {
    g_SoundSystem.EmitSoundDyn(_Edict, CHAN_VOICE, g_rglpszNihilanthQuotes[Math.RandomLong(0, g_rglpszNihilanthQuotes.length() - 1)], 1.0f, ATTN_NORM, 0, PITCH_NORM);
}

void ZM_UTIL_PlayRandomInfectionSound(edict_t@ _Edict) {
    g_SoundSystem.EmitSoundDyn(_Edict, CHAN_VOICE, g_rglpszInfectionSounds[Math.RandomLong(0, g_rglpszInfectionSounds.length() - 1)], 1.0f, ATTN_NORM, 0, PITCH_NORM);
}

void ZM_UTIL_PlayRandomPainSound(edict_t@ _Edict) {
    g_SoundSystem.EmitSoundDyn(_Edict, CHAN_STATIC, g_rglpszPainSounds[Math.RandomLong(0, g_rglpszPainSounds.length() - 1)], 1.0f, ATTN_NORM, 0, PITCH_NORM);
}

void ZM_UTIL_PlayRandomNemesisPainSound(edict_t@ _Edict) {
    g_SoundSystem.EmitSoundDyn(_Edict, CHAN_STATIC, g_rglpszNemesisPainSounds[Math.RandomLong(0, g_rglpszNemesisPainSounds.length() - 1)], 1.0f, ATTN_NORM, 0, PITCH_NORM);
}

void ZM_UTIL_PlayRandomDeathSound(edict_t@ _Edict) {
    g_SoundSystem.EmitSoundDyn(_Edict, CHAN_STATIC, g_rglpszDeathSounds[Math.RandomLong(0, g_rglpszDeathSounds.length() - 1)], 1.0f, ATTN_NORM, 0, PITCH_NORM);
}

int ZM_UTIL_CountAlivePlayers() {
    int nCount = 0;

    for (int idx = 1; idx <= g_Engine.maxClients; idx++) {
        CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(idx);
        if (pPlayer !is null && pPlayer.IsConnected() && (pPlayer.pev.health > 0.0f || pPlayer.IsAlive()) && !pPlayer.GetObserver().IsObserver() && pPlayer.Classify() == CLASS_PLAYER) nCount++;
    }
    
    return nCount;
}

int ZM_UTIL_CountPlayers() {
    int nCount = 0;

    for (int idx = 1; idx <= g_Engine.maxClients; idx++) {
        CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(idx);
        if (pPlayer !is null && pPlayer.IsConnected()) nCount++;
    }
    
    return nCount;
}

void PluginInit() {
    g_Module.ScriptInfo.SetAuthor("xWhitey");
    g_Module.ScriptInfo.SetContactInfo("@tyabus at Discord");
    
    CS16InitWeapons();
    
    g_dictPrimaryWeapons["Uzi"] = "weapon_uzi";
    g_dictPrimaryWeapons["MP5 Navy"] = "weapon_9mmAR";
    g_dictPrimaryWeapons["Auto Shotgun"] = "weapon_shotgun";
    g_dictPrimaryWeapons["M16 Carbine"] = "weapon_m16";
    g_dictPrimaryWeapons["AK47"] = "weapon_ak47";
    g_dictPrimaryWeapons["M4A1"] = "weapon_m4a1";
    g_dictPrimaryWeapons["P90"] = "weapon_p90";
    g_dictPrimaryWeapons["XM1014 Shotgun"] = "weapon_xm1014";
    
    g_dictSecondaryWeapons["Glock 17"] = "weapon_9mmhandgun";
    g_dictSecondaryWeapons["Desert Eagle .50 AE"] = "weapon_eagle";
    g_dictSecondaryWeapons[".357 Magnum"] = "weapon_357";
    g_dictSecondaryWeapons["Desert Eagle .50 Nighthawk"] = "weapon_csdeagle";
    g_dictSecondaryWeapons["Dual Elites"] = "weapon_dualelites";
    
    g_rgflLastZombieSentenceTime.resize(0);
    g_rgflLastZombieSentenceTime.resize(33);
    g_abZombies.resize(0);
    g_abZombies.resize(33);
    g_aiZombieBurnDuration.resize(0);
    g_aiZombieBurnDuration.resize(33);
    g_rglpfnBurningLoops.resize(0);
    g_rglpfnBurningLoops.resize(33);
    g_rglpfnFrozenLoops.resize(0);
    g_rglpfnFrozenLoops.resize(33);
    g_abIsZombieFrozen.resize(0);
    g_abIsZombieFrozen.resize(33);
    g_abIsNemesis.resize(0);
    g_abIsNemesis.resize(33);
    g_abIsAssassin.resize(0);
    g_abIsAssassin.resize(33);
    g_rglpBackupFrostNadePlayerData.resize(0);
    g_rglpBackupFrostNadePlayerData.resize(33);
    g_rglpfnUnfreezeScheds.resize(0);
    g_rglpfnUnfreezeScheds.resize(33);
    g_rglpShopMenuPlayerData.resize(0);
    g_rglpShopMenuPlayerData.resize(33);
    g_rglpBackupHumanTanksPlayerData.resize(0);
    g_rglpBackupHumanTanksPlayerData.resize(33);
    g_rglpBackupAssassinPlayerData.resize(0);
    g_rglpBackupAssassinPlayerData.resize(33);
    g_abHasRockTheVoted.resize(0);
    g_abHasRockTheVoted.resize(33);
    g_abZombieTrickyNightVision.resize(0);
    g_abZombieTrickyNightVision.resize(33);
    g_abSpectatorTrickyNightVision.resize(0);
    g_abSpectatorTrickyNightVision.resize(33);
    g_rgflLastSpectatorNightVisionUpdateTime.resize(0);
    g_rgflLastSpectatorNightVisionUpdateTime.resize(33);
    g_aapBoughtArms.resize(0);
    g_aapBoughtArms.resize(33);
    g_abHasBoughtInfiniteAmmo.resize(0);
    g_abHasBoughtInfiniteAmmo.resize(33);
    g_rglpVoteInProgressMaps.resize(0);
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_deko2"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_fdust_2x2"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_dust_2x2"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_ice_attack"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_ice_attack2"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_ice_attack3"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_italy"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_nuke"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_snowbase"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_snowbase2"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_texas_night"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_vendetta"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_winter_big"));
    g_rglpFastPlayerDataAccessor.resize(0);
    g_rglpFastPlayerDataAccessor.resize(33);
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("choose_campaign_dynamic"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_castlevania_t4"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_darkness_street_c2"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_forsaken_sanctum_p6"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_gorod_new"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_city_new"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_snowrooms2"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_tower4"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_dust_banzuke"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_ice_world_2"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_toxic_house3"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_prison"));
    g_rglpShopMenuPlayerDataFastAccessor.resize(0);
    g_rglpShopMenuPlayerDataFastAccessor.resize(33);
    g_rglpShopMenuPlayerData.resize(0);
    g_rglpShopMenuPlayerData.resize(33);
    g_alpBuyables.resize(0);
    cBuyable@ pSandbags = cBuyable(15, "Sandbags", ZM_ShopMenu_OnceSandbagsBoughtCallback);
    cBuyable@ pArmorVest = cBuyable(20, "Armor vest", ZM_ShopMenu_OnceArmorVestBoughtCallback);
    cBuyable@ pAntidot = cBuyable(30, "Antidot", ZM_ShopMenu_OnceAntidotBoughtCallback, true);
    cBuyable@ pInfiniteAmmo = cBuyable(30, "Infinite ammo", ZM_ShopMenu_OnceInfiniteAmmoBoughtCallback);
    cBuyable@ pRPG = cBuyable(40, "RPG", ZM_ShopMenu_OnceSpecialWeaponBoughtCallback);
    cBuyable@ pGluonGun = cBuyable(50, "Gluon Gun", ZM_ShopMenu_OnceSpecialWeaponBoughtCallback);
    cBuyable@ pTauCannon = cBuyable(35, "Tau Cannon", ZM_ShopMenu_OnceSpecialWeaponBoughtCallback);
    cBuyable@ pFrostGrenade = cBuyable(5, "Frost Grenade", ZM_ShopMenu_OnceSpecialWeaponBoughtCallback);
    cBuyable@ pFireGrenade = cBuyable(5, "Fire Grenade", ZM_ShopMenu_OnceSpecialWeaponBoughtCallback);
    cBuyable@ pFlareGrenade = cBuyable(5, "Flare Grenade", ZM_ShopMenu_OnceSpecialWeaponBoughtCallback);
    cBuyable@ pLasermine = cBuyable(35, "Lasermine", ZM_ShopMenu_OnceLasermineBoughtCallback);
    cBuyable@ pLasermineForZombies = cBuyable(35, "Lasermine", ZM_ShopMenu_OnceLasermineBoughtCallback, true);
    cBuyable@ pInfectionGrenade = cBuyable(30, "Infection grenade", ZM_ShopMenu_OnceSpecialWeaponBoughtCallback, true);
    g_alpBuyables.insertLast(@pSandbags);
    g_alpBuyables.insertLast(@pArmorVest);
    g_alpBuyables.insertLast(@pAntidot);
    g_alpBuyables.insertLast(@pInfiniteAmmo);
    g_alpBuyables.insertLast(@pRPG);
    g_alpBuyables.insertLast(@pGluonGun);
    g_alpBuyables.insertLast(@pTauCannon);
    g_alpBuyables.insertLast(@pFrostGrenade);
    g_alpBuyables.insertLast(@pFireGrenade);
    g_alpBuyables.insertLast(@pFlareGrenade);
    g_alpBuyables.insertLast(@pLasermine);
    g_alpBuyables.insertLast(@pLasermineForZombies);
    g_alpBuyables.insertLast(@pInfectionGrenade);
    g_bIsThereAVoteGoingOn = false;
    g_abCarriesNightvision.resize(0);
    g_abCarriesNightvision.resize(33);
    
    g_rglpZombieClasses.insertLast(CZombieClass("Classic", "=Balanced=", true, "zombie_source_v1_2", 2000.f, 800.f, 250.f, 115.f));
    g_rglpZombieClasses.insertLast(CZombieClass("Raptor", "HP-- Speed++ Knockback++", true, "infectedbusinessman", 1500.f, 780.f, 320.f, 135.f));
    g_rglpZombieClasses.insertLast(CZombieClass("Poison", "HP- Jump+ Knockback+", true, "mr_zombo_v2", 2200.f, 600.f, 240.f, 125.f));
    g_rglpZombieClasses.insertLast(CZombieClass("Big", "HP++ Speed- Knockback--", true, "re3_zombiefat", 3000.f, 800.f, 230.f, 100.f));
    g_rglpZombieClasses.insertLast(CZombieClass("Leech", "HP- Knockback+ Leech++", true, "cso_zombie2", 1800.f, 800.f, 260.f, 120.f));
    g_rglpZombieClasses.insertLast(CZombieClass("Nemesis", "", false, "zp_executioner_b", 4000.f, 600.f, 400.f, 100.f));
    g_rglpZombieClasses.insertLast(CZombieClass("Assassin", "", false, "archdevil", 1000.f, 400.f, 400.f, 100.f));
    
    g_rglpHumanClasses.insertLast(CHumanClass("Classic", "=Balanced=", 100.f, 0.f));
    g_rglpHumanClasses.insertLast(CHumanClass("Engineer", "Has a wrench", 100.f, 0.f));
    g_rglpHumanClasses.insertLast(CHumanClass("Mad Scientist", "Has night vision goggles", 100.f, 0.f));
    g_rglpHumanClasses.insertLast(CHumanClass("Tank", "Has armour on start", 100.f, 15.f));
    
    g_Hooks.RegisterHook(Hooks::Player::PlayerPreThink, @HOOKED_PlayerPreThink);
    g_Hooks.RegisterHook(Hooks::Player::PlayerPostThink, @HOOKED_PlayerPostThink);
    g_Hooks.RegisterHook(Hooks::Player::ClientPutInServer, @HOOKED_ClientPutInServer);
    g_Hooks.RegisterHook(Hooks::Player::ClientSay, @HOOKED_ClientSay);
    g_Hooks.RegisterHook(Hooks::Player::PlayerTakeDamage, @HOOKED_PlayerTakeDamage);
    g_Hooks.RegisterHook(Hooks::Player::ClientCommand, @HOOKED_ClientCommand);
    g_Hooks.RegisterHook(Hooks::Network::MessageBegin, @HOOKED_MessageBegin);
    g_Hooks.RegisterHook(Hooks::Player::PlayerKilled, @HOOKED_PlayerKilled);
    g_Hooks.RegisterHook(Hooks::Player::ClientDisconnect, @HOOKED_ClientDisconnect);
    g_Hooks.RegisterHook(Hooks::Game::MapChange, @HOOKED_MapChange);
}

void MapInit() {
    g_iTimesExtended = 0;
    g_bMatchStarted = false;
    g_bMatchStarting = false;
    g_bIsThereAVoteGoingOn = false;
    g_abHasRockTheVoted.resize(0);
    g_abHasRockTheVoted.resize(33);
    g_ahAssassins.resize(0);
    g_ahNemesises.resize(0);
    g_ahHumanTanks.resize(0);
    g_abZombies.resize(0);
    g_abZombies.resize(33);
    g_abIsSniper.resize(0);
    g_abIsSniper.resize(33);
    g_abIsSurvivor.resize(0);
    g_abIsSurvivor.resize(33);
    g_ahZombies.resize(0);
    for (uint idx = 0; idx < g_rglpPlayerDatas.length(); idx++) {
        CPlayerData@ pData = g_rglpPlayerDatas[idx];
        pData.m_bHasGotFirstWeapon = false;
        pData.m_bHasGotSecondaryWeapon = false;
    }
    if (g_lpfnPreMatchStart !is null && !g_lpfnPreMatchStart.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(@g_lpfnPreMatchStart);
        @g_lpfnPreMatchStart = null;
    }
    if (g_lpfnPostMatchStart !is null && !g_lpfnPostMatchStart.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(@g_lpfnPostMatchStart);
        @g_lpfnPostMatchStart = null;
    }
    if (g_lpfnMatchStartCountdown !is null && !g_lpfnMatchStartCountdown.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(@g_lpfnMatchStartCountdown);
        @g_lpfnMatchStartCountdown = null;
    }
    if (g_lpfnUpdateTimer !is null && !g_lpfnUpdateTimer.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(@g_lpfnUpdateTimer);
        @g_lpfnUpdateTimer = null;
    }
    if (g_lpfnForceZombieModels !is null && !g_lpfnForceZombieModels.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(@g_lpfnForceZombieModels);
        @g_lpfnForceZombieModels = null;
    }
    if (g_lpfnSafety !is null && !g_lpfnSafety.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(@g_lpfnSafety);
        @g_lpfnSafety = null;
    }
    if (g_lpfnRespawnPlayers !is null && !g_lpfnRespawnPlayers.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(@g_lpfnRespawnPlayers);
        @g_lpfnRespawnPlayers = null;
    }
    if (g_lpfnResetPlayerStates !is null && !g_lpfnResetPlayerStates.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(@g_lpfnResetPlayerStates);
        @g_lpfnResetPlayerStates = null;
    }
    if (g_lpfnTryStartingAMatch !is null && !g_lpfnTryStartingAMatch.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(g_lpfnTryStartingAMatch);
        @g_lpfnTryStartingAMatch = null;
    }
    if (g_lpfnNotifier !is null && !g_lpfnNotifier.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(g_lpfnNotifier);
        @g_lpfnNotifier = null;
    }
    if (g_lpfnOpenWeaponSelectMenu !is null && !g_lpfnOpenWeaponSelectMenu.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(g_lpfnOpenWeaponSelectMenu);
        @g_lpfnOpenWeaponSelectMenu = null;
    }
    if (g_lpfnMakeHumanTanksShiny !is null && !g_lpfnMakeHumanTanksShiny.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(g_lpfnMakeHumanTanksShiny);
        @g_lpfnMakeHumanTanksShiny = null;
    }
    if (g_lpfnMakeAssassinShiny !is null && !g_lpfnMakeAssassinShiny.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(g_lpfnMakeAssassinShiny);
        @g_lpfnMakeAssassinShiny = null;
    }
    if (g_lpfnCalculateVoteResults !is null && !g_lpfnCalculateVoteResults.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(g_lpfnCalculateVoteResults);
        @g_lpfnCalculateVoteResults = null;
    }
    if (g_lpfnUpdateWalkingPlayerAmmoPackHud !is null && !g_lpfnUpdateWalkingPlayerAmmoPackHud.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(g_lpfnUpdateWalkingPlayerAmmoPackHud);
        @g_lpfnUpdateWalkingPlayerAmmoPackHud = null;
    }
    if (g_lpfnRemovePipeWrenchesFromNonEngineers !is null && !g_lpfnRemovePipeWrenchesFromNonEngineers.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(@g_lpfnRemovePipeWrenchesFromNonEngineers);
        @g_lpfnRemovePipeWrenchesFromNonEngineers = null;
    }
    if (g_lpfnWalkingMadScientistNightVisionGogglesThink !is null && !g_lpfnWalkingMadScientistNightVisionGogglesThink.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(@g_lpfnWalkingMadScientistNightVisionGogglesThink);
        @g_lpfnWalkingMadScientistNightVisionGogglesThink = null;
    }
    if (g_lpfnMatchCleanup !is null && !g_lpfnMatchCleanup.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(@g_lpfnMatchCleanup);
        @g_lpfnMatchCleanup = null;
    }
    
    string szMapname = g_Engine.mapname;
    
    if (szMapname.Find("hns") == 0) {
        g_bIsZM = false;
        
        return;
    }
    
    if (szMapname.Find("qsg") == 0) {
        g_bIsZM = false;
        
        return;
    }
    
    if (szMapname == "ctf_warforts") {
        g_bIsZM = false;
        g_EngineFuncs.ServerCommand("hostname \"Half-Life C - CTF Warforts\"\n");
        
        return;
    }
    
    if (szMapname.Find("zm") == 0) {
        g_bIsZM = true;
        g_SoundSystem.PrecacheSound("hlcancer/zombiemod/countdown/one.wav");
        g_SoundSystem.PrecacheSound("hlcancer/zombiemod/countdown/two.wav");
        g_SoundSystem.PrecacheSound("hlcancer/zombiemod/countdown/three.wav");
        g_SoundSystem.PrecacheSound("hlcancer/zombiemod/countdown/four.wav");
        g_SoundSystem.PrecacheSound("hlcancer/zombiemod/countdown/five.wav");
        g_SoundSystem.PrecacheSound("hlcancer/zombiemod/countdown/six.wav");
        g_SoundSystem.PrecacheSound("hlcancer/zombiemod/countdown/seven.wav");
        g_SoundSystem.PrecacheSound("hlcancer/zombiemod/countdown/eight.wav");
        g_SoundSystem.PrecacheSound("hlcancer/zombiemod/countdown/nine.wav");
        g_SoundSystem.PrecacheSound("hlcancer/zombiemod/countdown/ten.wav");
        
        g_Game.PrecacheGeneric("sound/hlcancer/zombiemod/countdown/one.wav");
        g_Game.PrecacheGeneric("sound/hlcancer/zombiemod/countdown/two.wav");
        g_Game.PrecacheGeneric("sound/hlcancer/zombiemod/countdown/three.wav");
        g_Game.PrecacheGeneric("sound/hlcancer/zombiemod/countdown/four.wav");
        g_Game.PrecacheGeneric("sound/hlcancer/zombiemod/countdown/five.wav");
        g_Game.PrecacheGeneric("sound/hlcancer/zombiemod/countdown/six.wav");
        g_Game.PrecacheGeneric("sound/hlcancer/zombiemod/countdown/seven.wav");
        g_Game.PrecacheGeneric("sound/hlcancer/zombiemod/countdown/eight.wav");
        g_Game.PrecacheGeneric("sound/hlcancer/zombiemod/countdown/nine.wav");
        g_Game.PrecacheGeneric("sound/hlcancer/zombiemod/countdown/ten.wav");
        
        if (!g_CustomEntityFuncs.IsCustomEntity("zpc_sandbags")) {
            g_CustomEntityFuncs.RegisterCustomEntity("CSandbags", "zpc_sandbags");
            g_Game.PrecacheOther("zpc_sandbags");
        }
        
        if (!g_CustomEntityFuncs.IsCustomEntity("zpc_lasermine")) {
            g_CustomEntityFuncs.RegisterCustomEntity("CLaserMine", "zpc_lasermine");
            g_Game.PrecacheOther("zpc_lasermine");
        }
        
        if (!g_CustomEntityFuncs.IsCustomEntity("weapon_zombieknife")) {
            g_CustomEntityFuncs.RegisterCustomEntity("CZombieKnife", "weapon_zombieknife");
            g_ItemRegistry.RegisterWeapon("weapon_zombieknife", "zombie_plague/weapons", "", "", "");
        }
        
        if (!g_CustomEntityFuncs.IsCustomEntity("weapon_executioner_axe")) {
            g_CustomEntityFuncs.RegisterCustomEntity("CExecutionerAxe", "weapon_executioner_axe");
            g_ItemRegistry.RegisterWeapon("weapon_executioner_axe", "zombie_plague/weapons", "", "", "");
        }
        
        if (!g_CustomEntityFuncs.IsCustomEntity("zpc_smokenade")) {
            g_CustomEntityFuncs.RegisterCustomEntity("CCustomGrenade", "zpc_smokenade");
            g_CustomEntityFuncs.RegisterCustomEntity("CCustomFrostGrenade", "zpc_frostnade");
            g_CustomEntityFuncs.RegisterCustomEntity("CCustomFireGrenade", "zpc_firenade");
            g_CustomEntityFuncs.RegisterCustomEntity("CZombieInfectionGrenade", "zpc_infectiongrenade");
            g_CustomEntityFuncs.RegisterCustomEntity("CZombieJumpGrenade", "zpc_jumpgrenade");
            g_CustomEntityFuncs.RegisterCustomEntity("CCustomGrenadeWpn", "weapon_flaregrenade");
            g_CustomEntityFuncs.RegisterCustomEntity("CCustomFrostGrenadeWpn", "weapon_frostgrenade");
            g_CustomEntityFuncs.RegisterCustomEntity("CCustomFireGrenadeWpn", "weapon_firegrenade");
            g_CustomEntityFuncs.RegisterCustomEntity("CZombieInfectionGrenadeWpn", "weapon_infectgrenade");
            g_CustomEntityFuncs.RegisterCustomEntity("CZombieJumpGrenadeWpn", "weapon_jumpgrenade");
            g_ItemRegistry.RegisterWeapon("weapon_frostgrenade", "zombie_plague/weapons", "weapon_frostgrenade", "", "weapon_frostgrenade");
            g_ItemRegistry.RegisterWeapon("weapon_flaregrenade", "zombie_plague/weapons", "weapon_flaregrenade", "", "weapon_flaregrenade");
            g_ItemRegistry.RegisterWeapon("weapon_firegrenade", "zombie_plague/weapons", "weapon_firegrenade", "", "weapon_firegrenade");
            g_ItemRegistry.RegisterWeapon("weapon_infectgrenade", "zombie_plague/weapons", "weapon_infectgrenade", "", "weapon_infectgrenade");
            g_ItemRegistry.RegisterWeapon("weapon_jumpgrenade", "zombie_plague/weapons", "weapon_jumpgrenade", "", "weapon_jumpgrenade");
        }
        
        CS16OnMapInit();
        
        for (uint idx = 0; idx < g_rglpZombieClasses.length(); idx++) {
            CZombieClass@ pKlass = g_rglpZombieClasses[idx];
            g_Game.PrecacheModel("models/player/" + pKlass.m_lpszPlayerModel + "/" + pKlass.m_lpszPlayerModel + ".mdl");
        }
        
        g_Game.PrecacheGeneric("gfx/env/nightbk.bmp");
        g_Game.PrecacheGeneric("gfx/env/nightdn.bmp");
        g_Game.PrecacheGeneric("gfx/env/nightft.bmp");
        g_Game.PrecacheGeneric("gfx/env/nightlf.bmp");
        g_Game.PrecacheGeneric("gfx/env/nightrt.bmp");
        g_Game.PrecacheGeneric("gfx/env/nightup.bmp");
        
        g_Game.PrecacheGeneric("gfx/env/nightbk.tga");
        g_Game.PrecacheGeneric("gfx/env/nightdn.tga");
        g_Game.PrecacheGeneric("gfx/env/nightft.tga");
        g_Game.PrecacheGeneric("gfx/env/nightlf.tga");
        g_Game.PrecacheGeneric("gfx/env/nightrt.tga");
        g_Game.PrecacheGeneric("gfx/env/nightup.tga");
        
        for (uint idx = 0; idx < g_rglpszInfectionSounds.length(); idx++) {
            g_Game.PrecacheGeneric("sound/" + g_rglpszInfectionSounds[idx]);
            g_SoundSystem.PrecacheSound(g_rglpszInfectionSounds[idx]);
        }
        
        for (uint idx = 0; idx < g_rglpszPainSounds.length(); idx++) {
            g_Game.PrecacheGeneric("sound/" + g_rglpszPainSounds[idx]);
            g_SoundSystem.PrecacheSound(g_rglpszPainSounds[idx]);
        }
        
        for (uint idx = 0; idx < g_rglpszNemesisPainSounds.length(); idx++) {
            g_Game.PrecacheGeneric("sound/" + g_rglpszNemesisPainSounds[idx]);
            g_SoundSystem.PrecacheSound(g_rglpszNemesisPainSounds[idx]);
        }
        
        for (uint idx = 0; idx < g_rglpszDeathSounds.length(); idx++) {
            g_Game.PrecacheGeneric("sound/" + g_rglpszDeathSounds[idx]);
            g_SoundSystem.PrecacheSound(g_rglpszDeathSounds[idx]);
        }
        
        for (uint idx = 0; idx < g_rglpszNihilanthQuotes.length(); idx++) {
            g_Game.PrecacheGeneric("sound/" + g_rglpszNihilanthQuotes[idx]);
            g_SoundSystem.PrecacheSound(g_rglpszNihilanthQuotes[idx]);
        }
        
        for (uint idx = 0; idx < g_rglpszZombiesWinSounds.length(); idx++) {
            g_Game.PrecacheGeneric("sound/" + g_rglpszZombiesWinSounds[idx]);
            g_SoundSystem.PrecacheSound(g_rglpszZombiesWinSounds[idx]);
        }
        
        for (uint idx = 0; idx < g_rglpszZombieBurnSounds.length(); idx++) {
            g_Game.PrecacheGeneric("sound/" + g_rglpszZombieBurnSounds[idx]);
            g_SoundSystem.PrecacheSound(g_rglpszZombieBurnSounds[idx]);
        }
        
        for (uint idx = 0; idx < g_rglpszRoundStartSounds.length(); idx++) {
            g_Game.PrecacheGeneric("sound/" + g_rglpszRoundStartSounds[idx]);
            g_SoundSystem.PrecacheSound(g_rglpszRoundStartSounds[idx]);
        }
        
        for (uint idx = 0; idx < g_rglpszNemesisRoundStartSounds.length(); idx++) {
            g_Game.PrecacheGeneric("sound/" + g_rglpszNemesisRoundStartSounds[idx]);
            g_SoundSystem.PrecacheSound(g_rglpszNemesisRoundStartSounds[idx]);
        }
        
        for (uint idx = 0; idx < g_rglpszHumanTankRoundStartSounds.length(); idx++) {
            g_Game.PrecacheGeneric("sound/" + g_rglpszHumanTankRoundStartSounds[idx]);
            g_SoundSystem.PrecacheSound(g_rglpszHumanTankRoundStartSounds[idx]);
        }
        
        g_Game.PrecacheGeneric("sound/zombie_plague/zombie_fall1.wav");
        
        g_SoundSystem.PrecacheSound("zombie_plague/zombie_fall1.wav");
        
        g_Game.PrecacheGeneric("sound/zombie_plague/win_humans1.wav");
        g_SoundSystem.PrecacheSound("zombie_plague/win_humans1.wav");
        
        g_Game.PrecacheGeneric("sound/zombie_plague/win_humans2.wav");
        g_SoundSystem.PrecacheSound("zombie_plague/win_humans2.wav");
        
        g_EngineFuncs.ServerCommand("hostname \"Half-Life C - Zombie Plague OG\"\n");
        g_EngineFuncs.ServerCommand("mp_weapon_droprules 0\n");
        g_EngineFuncs.ServerCommand("mp_ammo_droprules 0\n");
        g_EngineFuncs.ServerCommand("mp_survival_supported 1\n");
        g_EngineFuncs.ServerCommand("mp_survival_startdelay 25\n");
        g_EngineFuncs.ServerCommand("mp_dropweapons 0\n");
        g_EngineFuncs.ServerCommand("mp_teamplay 1\n");
        g_EngineFuncs.ServerCommand("mp_classic_mode 0\n");
        g_EngineFuncs.ServerCommand("sk_player_head 3\n");
        g_EngineFuncs.ServerCommand("sv_skyname night\n");
        
        for (uint idx = 0; idx < g_rglpPlayerDatas.length(); idx++) {
            CPlayerData@ pData = g_rglpPlayerDatas[idx];
            pData.m_bHasGotFirstWeapon = false;
            pData.m_bHasGotSecondaryWeapon = false;
            if (pData.m_lpBackupZombieClass is null)
                continue;
            @pData.m_lpZombieClass = @pData.m_lpBackupZombieClass;
            @pData.m_lpBackupZombieClass = null;
        }
        
        ZM_UTIL_ParseShopPlayerData();
        @g_lpfnNotifier = g_Scheduler.SetTimeout("Notifier", 30.f);
    } else {
        g_bIsZM = false;
        g_EngineFuncs.ServerCommand("mp_weapon_droprules 1\n");
        g_EngineFuncs.ServerCommand("mp_ammo_droprules 1\n");
        g_EngineFuncs.ServerCommand("mp_dropweapons 1\n");
        g_EngineFuncs.ServerCommand("sk_player_head 1\n");
    }
    
    g_EngineFuncs.ServerExecute();
}

class CBreakable {
    CBreakable() {}

    string m_lpszModel;
    Vector m_vecOrigin;
    float m_flHealth;
    float m_flMaxHealth;
    int m_iMaterial;
}
 
array<CBreakable@> g_rgpBreakables;

void MapStart() {
    if (!g_bIsZM) return;
    
    g_rgpBreakables.resize(0);

    for (int idx = 0; idx < g_Engine.maxEntities; idx++) {
        CBaseEntity@ pEntity = g_EntityFuncs.Instance(idx);
        if (pEntity !is null and pEntity.pev !is null) {
            if (pEntity.GetClassname() == "func_breakable") {
                CBreakable@ pBreakable = CBreakable();
                pBreakable.m_lpszModel = string(pEntity.pev.model);
                pBreakable.m_vecOrigin = pEntity.pev.origin;
                pBreakable.m_flMaxHealth = pEntity.pev.max_health;
                pBreakable.m_flHealth = pEntity.pev.health;
                
                array<Vector> rgvecSides = { Vector(0.f, 0.f, -4.f) /* Downwards */, Vector(0.f, 0.f, 4.f) /* Upwards */, Vector(0.f, 4.f, 0.f) /* Forward */, Vector(0.f, -4.f, 0.f) /* Back */,
                                                Vector(4.f, 0.f, 0.f) /* Right */, Vector(0.f, 4.f, 0.f) /* Left */ };
                array<TraceResult> rgTraceResults;
                rgTraceResults.resize(rgvecSides.length());
                for (uint j = 0; j < rgvecSides.length(); j++) {
                    g_Utility.TraceLine(rgvecSides[j], pBreakable.m_vecOrigin, dont_ignore_monsters, dont_ignore_glass, null, rgTraceResults[j]);
                }
                string szTextureName = "hlclikesthistrickytexturenamejusttobesurenobodyelseusesityeahyouknowthat"; //A really long name just to be sure we haven't found the proper texture name.
                char cTextureType = 'Z'; //specifying illegal texture type so we'll know if all tracelines have failed (why?)
                for (uint k = 0; k < rgTraceResults.length(); k++) {
                    if (rgTraceResults[k].fStartSolid != 0 || rgTraceResults[k].fAllSolid != 0) continue;
                    szTextureName = g_Utility.TraceTexture(null, rgvecSides[k], pBreakable.m_vecOrigin);
                    //g_Log.PrintF(szTextureName + "\n");
                    cTextureType = g_SoundSystem.FindMaterialType(szTextureName);
                    break;
                }
                if (szTextureName == "hlclikesthistrickytexturenamejusttobesurenobodyelseusesityeahyouknowthat") { //We've failed to determine the texture type, damn!
                    cTextureType = 'Y'; //Fallback it to glass texture type.
                    //g_Log.PrintF("not found\n");
                } else {
                    //g_Log.PrintF(string(cTextureType) + "\n");
                }
                
                //Don't even try converting this into a `switch`. You will fail.
                if (cTextureType == CHAR_TEX_GLASS) {
                    pBreakable.m_iMaterial = 0;
                } else if (cTextureType == CHAR_TEX_WOOD) {
                    pBreakable.m_iMaterial = 1;
                } else if (cTextureType == CHAR_TEX_WOOD) {
                    pBreakable.m_iMaterial = 1;
                } else if (cTextureType == CHAR_TEX_METAL) {
                    pBreakable.m_iMaterial = 2;
                } else if (cTextureType == CHAR_TEX_FLESH) {
                    pBreakable.m_iMaterial = 3;
                } else if (cTextureType == CHAR_TEX_COMPUTER) {
                    pBreakable.m_iMaterial = 6;
                } else {
                    pBreakable.m_iMaterial = 8;
                }
                
                g_rgpBreakables.insertLast(@pBreakable);
            }
        }
    }

    g_EngineFuncs.LightStyle(0 , "c");
    if (g_lpfnTryStartingAMatch is null || g_lpfnTryStartingAMatch.HasBeenRemoved()) {
        @g_lpfnTryStartingAMatch = g_Scheduler.SetTimeout("TryStartingAMatch", 3.0f);
    }
}

void TryStartingAMatch() {
    if (!g_bIsZM) return;
    
    if (g_lpfnTryStartingAMatch !is null && !g_lpfnTryStartingAMatch.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(g_lpfnTryStartingAMatch);
        @g_lpfnTryStartingAMatch = null;
    }
    if (ZM_UTIL_CountPlayers() < 1) {
        @g_lpfnTryStartingAMatch = g_Scheduler.SetTimeout("TryStartingAMatch", 5.0f);
        return;
    }
    if (g_bMatchStarted || g_bMatchStarting) return;
    if (g_lpfnPreMatchStart !is null && !g_lpfnPreMatchStart.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(g_lpfnPreMatchStart);
        @g_lpfnPreMatchStart = null;
    }
    
    @g_lpfnPreMatchStart = g_Scheduler.SetTimeout("PreMatchStart", 15.f);
}

void MatchStartCountdown() {
    if (g_lpfnMatchStartCountdown !is null) {
        g_Scheduler.RemoveTimer(@g_lpfnMatchStartCountdown);
        @g_lpfnMatchStartCountdown = null;
    }
    
    if (!g_bMatchStarting) return;
    
    if (g_iCurrentCountdownNumber == 0) {
        return;
    }
        
    HUDTextParams params;
    params.r1 = 255;
    params.g1 = 0;
    params.b1 = 0;
    params.a1 = 160;
    params.a2 = 160;
    params.x = -1.0f;
    params.y = 0.25f;
    params.effect = 0;
    params.fadeinTime = 0.0f;
    params.fadeoutTime = 0.5f;
    params.holdTime = 1.0f;
    params.channel = 4;
    
    g_PlayerFuncs.HudMessageAll(params, "Infection in " + string(g_iCurrentCountdownNumber));
    
    if (g_iCurrentCountdownNumber <= 10) {
        ZM_UTIL_SendSpeakSoundStuffTextMsg("hlcancer/zombiemod/countdown/" + ZM_UTIL_CountdownNumberToString(g_iCurrentCountdownNumber));
        @g_lpfnMatchStartCountdown = g_Scheduler.SetTimeout("MatchStartCountdown", 1.0f);
        g_iCurrentCountdownNumber--;
    } else if (g_iCurrentCountdownNumber > 10) {
        g_iCurrentCountdownNumber--;
        @g_lpfnMatchStartCountdown = g_Scheduler.SetTimeout("MatchStartCountdown", 1.0f);
    }
}

void PreMatchStart() {
    if (g_lpfnPreMatchStart !is null && !g_lpfnPreMatchStart.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(g_lpfnPreMatchStart);
        @g_lpfnPreMatchStart = null;
    }
    
    if (g_lpfnUpdateWalkingPlayerAmmoPackHud is null || g_flLastUpdateWalkingPlayerAmmoPackHudTime <= g_Engine.time + 5.0f || g_lpfnUpdateWalkingPlayerAmmoPackHud.HasBeenRemoved()) {
        @g_lpfnUpdateWalkingPlayerAmmoPackHud = g_Scheduler.SetTimeout("UpdateWalkingPlayerAmmoPackHud", 0.1f);
    }
    
    if (g_lpfnWalkingMadScientistNightVisionGogglesThink is null || g_lpfnWalkingMadScientistNightVisionGogglesThink.HasBeenRemoved())
        @g_lpfnWalkingMadScientistNightVisionGogglesThink = g_Scheduler.SetTimeout("WalkingMadScientistNightVisionGogglesThink", 0.1f);
    
    for (int idx = 0; idx < g_Engine.maxEntities; idx++) {
        CBaseEntity@ pEntity = g_EntityFuncs.Instance(idx);
        if (pEntity !is null and pEntity.pev !is null) {
            if (pEntity.GetClassname() == "zpc_sandbags" || pEntity.GetClassname() == "zpc_lasermine")
                g_EntityFuncs.Remove(pEntity);
            //if (pEntity.GetClassname() == "func_breakable") {
            //    g_EntityFuncs.Remove(pEntity);
            //}
        }
    }
   /* for (uint idx = 0; idx < g_rgpBreakables.length(); idx++) {
        CBreakable@ pBreakable = @g_rgpBreakables[idx];
        CBaseEntity@ pNewBreakable = g_EntityFuncs.Create("func_breakable", pBreakable.m_vecOrigin, g_vecZero, true, null);
        g_EntityFuncs.SetOrigin(pNewBreakable, pBreakable.m_vecOrigin);
        g_EntityFuncs.SetModel(pNewBreakable, pBreakable.m_lpszModel);
        g_EntityFuncs.DispatchKeyValue(pNewBreakable.edict(), "material", pBreakable.m_iMaterial);
        pNewBreakable.pev.max_health = pBreakable.m_flMaxHealth;
        pNewBreakable.pev.health = pBreakable.m_flHealth;
        g_EntityFuncs.DispatchSpawn(pNewBreakable.edict());
    }*/
    
    string szMapName = g_Engine.mapname;
    
    if (szMapName.Find("zm_") == String::INVALID_INDEX && szMapName.Find("ze_") == String::INVALID_INDEX) {
        return;
    }
    
    if (g_bMatchStarted) return;
    
    g_iCurrentCountdownNumber = 20;
    g_rgflLastZombieSentenceTime.resize(0);
    g_rgflLastZombieSentenceTime.resize(33);
    g_abZombies.resize(0);
    g_abZombies.resize(33);
    g_abIsSniper.resize(0);
    g_abIsSniper.resize(33);
    g_abIsSurvivor.resize(0);
    g_abIsSurvivor.resize(33);
    g_aiZombieBurnDuration.resize(0);
    g_aiZombieBurnDuration.resize(33);
    g_rglpfnBurningLoops.resize(0);
    g_rglpfnBurningLoops.resize(33);
    g_rglpfnFrozenLoops.resize(0);
    g_rglpfnFrozenLoops.resize(33);
    g_abIsZombieFrozen.resize(0);
    g_abIsZombieFrozen.resize(33);
    g_abIsNemesis.resize(0);
    g_abIsNemesis.resize(33);
    g_abIsAssassin.resize(0);
    g_abIsAssassin.resize(33);
    g_rglpBackupFrostNadePlayerData.resize(0);
    g_rglpBackupFrostNadePlayerData.resize(33);
    g_rglpfnUnfreezeScheds.resize(0);
    g_rglpfnUnfreezeScheds.resize(33);
    g_aapBoughtArms.resize(0);
    g_aapBoughtArms.resize(33);
    g_abHasBoughtInfiniteAmmo.resize(0);
    g_abHasBoughtInfiniteAmmo.resize(33);
    g_rgiWrenchHitCount.resize(0);
    g_rgiWrenchHitCount.resize(33);
    
    @g_lpfnOpenWeaponSelectMenu = g_Scheduler.SetTimeout("OpenWeaponSelectMenu", 1.0f);

    g_bMatchStarting = true;
    @g_lpfnPostMatchStart = g_Scheduler.SetTimeout("PostMatchStart", 21.0f);
    @g_lpfnMatchStartCountdown = g_Scheduler.SetTimeout("MatchStartCountdown", 0.0f);
}

void OpenWeaponSelectMenu() {
    if (g_lpfnOpenWeaponSelectMenu !is null && !g_lpfnOpenWeaponSelectMenu.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(g_lpfnOpenWeaponSelectMenu);
        @g_lpfnOpenWeaponSelectMenu = null;
    }

    if (g_lpChoosePrimaryWeaponMenu is null) {
        @g_lpChoosePrimaryWeaponMenu = CCustomTextMenu(ZM_ChoosePrimaryWeaponMenuCB, false);
        g_lpChoosePrimaryWeaponMenu.MakeExitButtonTheSameColourAsTitle();
        g_lpChoosePrimaryWeaponMenu.SetItemDelimeter(':');
        g_lpChoosePrimaryWeaponMenu.SetTitle("Primary weapon");
        g_lpChoosePrimaryWeaponMenu.AddItem("Uzi");
        g_lpChoosePrimaryWeaponMenu.AddItem("MP5 Navy");
        g_lpChoosePrimaryWeaponMenu.AddItem("Auto Shotgun");
        g_lpChoosePrimaryWeaponMenu.AddItem("M16 Carbine");
        g_lpChoosePrimaryWeaponMenu.AddItem("AK47");
        g_lpChoosePrimaryWeaponMenu.AddItem("M4A1");
        g_lpChoosePrimaryWeaponMenu.AddItem("P90");
        g_lpChoosePrimaryWeaponMenu.AddItem("XM1014 Shotgun");
        g_lpChoosePrimaryWeaponMenu.Register();
    }
    
    if (g_lpChooseSecondaryWeaponMenu is null) {
        @g_lpChooseSecondaryWeaponMenu = CCustomTextMenu(ZM_ChooseSecondaryWeaponMenuCB, false);
        g_lpChooseSecondaryWeaponMenu.MakeExitButtonTheSameColourAsTitle();
        g_lpChooseSecondaryWeaponMenu.SetItemDelimeter(':');
        g_lpChooseSecondaryWeaponMenu.SetTitle("Secondary weapon");
        g_lpChooseSecondaryWeaponMenu.AddItem("Glock 17");
        g_lpChooseSecondaryWeaponMenu.AddItem("Desert Eagle .50 AE");
        g_lpChooseSecondaryWeaponMenu.AddItem(".357 Magnum");
        g_lpChooseSecondaryWeaponMenu.AddItem("Desert Eagle .50 Nighthawk");
        g_lpChooseSecondaryWeaponMenu.AddItem("Dual Elites");
        g_lpChooseSecondaryWeaponMenu.Register();
    }
    for (int idx = 1; idx <= g_Engine.maxClients; idx++) {
        CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(idx);
        if (pPlayer !is null && pPlayer.IsConnected()) {
            g_lpChoosePrimaryWeaponMenu.Open(0, 0, pPlayer);
            pPlayer.GiveNamedItem("weapon_frostgrenade", 0, 1);
            pPlayer.GiveNamedItem("weapon_flaregrenade", 0, 1);
            pPlayer.GiveNamedItem("weapon_firegrenade", 0, 1);
            
            CBasePlayerItem@ pItem;
            CBasePlayerWeapon@ pWeapon;
            for (uint j = 0; j < 10; j++) {
                @pItem = pPlayer.m_rgpPlayerItems(j);
                while (pItem !is null) {
                    @pWeapon = pItem.GetWeaponPtr();
                            
                    if (pWeapon.GetClassname().Find("grenade") != String::INVALID_INDEX) {
                        int iPrimaryIdx = pWeapon.PrimaryAmmoIndex();
                        if (iPrimaryIdx != -1) {
                            pPlayer.m_rgAmmo(iPrimaryIdx, 1);
                        }
                    }
                            
                    @pItem = cast<CBasePlayerItem@>(pItem.m_hNextItem.GetEntity());
                }
            }
            
            string szSteamID = g_EngineFuncs.GetPlayerAuthId(pPlayer.edict());
            CPlayerData@ pData = ZM_UTIL_GetPlayerDataBySteamID(szSteamID);
            if (pData is null) continue;
            pPlayer.pev.health = pData.m_lpHumanClass.m_flHealth;
            pPlayer.pev.max_health = pData.m_lpHumanClass.m_flHealth;
            pPlayer.pev.armorvalue = pData.m_lpHumanClass.m_flArmour;
            if (pData.m_lpHumanClass.m_lpszName == "Engineer") {
                CBaseEntity@ lpWeapon = g_EntityFuncs.Create("weapon_pipewrench", g_vecZero, g_vecZero, true, null);
                lpWeapon.pev.spawnflags |= (SF_NORESPAWN | SF_CREATEDWEAPON);
                g_EntityFuncs.DispatchSpawn(lpWeapon.edict());
                lpWeapon.Touch(pPlayer);
            }
        }
    }
}

void PostMatchStart() {
    if (g_lpfnPostMatchStart !is null && !g_lpfnPostMatchStart.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(g_lpfnPostMatchStart);
        @g_lpfnPostMatchStart = null;
    }
    
    if (g_bMatchStarted) return;
    
    g_rglpBackupHumanTanksPlayerData.resize(0);
    g_rglpBackupHumanTanksPlayerData.resize(33);
    g_rglpBackupAssassinPlayerData.resize(0);
    g_rglpBackupAssassinPlayerData.resize(33);
        
    g_bMatchStarting = false;
    g_bMatchStarted = true;
    g_iTimeLeft = 300; //5 minutes
    
    array<CBasePlayer@> aPlayers;
    
    for (int idx = 1; idx <= g_Engine.maxClients; idx++) {
        CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(idx);
        if (pPlayer !is null && pPlayer.IsConnected()) {
            aPlayers.insertLast(@pPlayer);
        
            string szSteamID = g_EngineFuncs.GetPlayerAuthId(pPlayer.edict());
            CPlayerData@ pData = ZM_UTIL_GetPlayerDataBySteamID(szSteamID);
            if (pData is null) {
                @pData = CPlayerData(szSteamID);
                g_rglpPlayerDatas.insertLast(pData);
            }
            KeyValueBuffer@ pInfo = g_EngineFuncs.GetInfoKeyBuffer(pPlayer.edict());
            string szModel = pInfo.GetValue("model");
            pData.m_lpszBackupModel = (szModel.IsEmpty() ? "gordon" : szModel);
            if (pData.m_lpBackupZombieClass !is null) {
                @pData.m_lpZombieClass = pData.m_lpBackupZombieClass;
                @pData.m_lpBackupZombieClass = null;
            }
            if (pData.m_lpZombieClass.m_lpszName == "Assassin" || pData.m_lpZombieClass.m_lpszName == "Nemesis") {
                @pData.m_lpZombieClass = g_rglpZombieClasses[0];
            }
            
            if (!pPlayer.IsAlive()) g_PlayerFuncs.RespawnPlayer(pPlayer, true, true);
            pPlayer.pev.health = 100;
            pPlayer.pev.armorvalue = 0;
        }
    }
    
    bool bNemesisRound = false; //(Math.RandomLong(0, 99) < 10); //10% chance
    bool bSurvivorRound = bNemesisRound ? false : (Math.RandomLong(0, 99) < 5); //5% chance
    bool bSniperRound = (bNemesisRound || bSurvivorRound) ? false : (Math.RandomLong(0, 99) < 5); //5% chance
    bool bSwarmRound = (bNemesisRound || bSurvivorRound || bSniperRound) ? false : (Math.RandomLong(0, 99) < 5); //5% chance
    bool bAssassinRound = (bNemesisRound || bSurvivorRound || bSniperRound || bSwarmRound) ? false : (Math.RandomLong(0, 99) < 5); //5% chance
    bool bNightmareMode = (bNemesisRound || bSurvivorRound || bSniperRound || bSwarmRound || bAssassinRound) ? false : (Math.RandomLong(0, 99) < 5); //5% chance
    bool bArmageddonMode = (bNemesisRound || bSurvivorRound || bSniperRound || bSwarmRound || bAssassinRound || bNightmareMode) ? false : (Math.RandomLong(0, 99) < 5); //5% chance
    
    //Dark Harvest - added on 06/21/2024 - In this mode we have an Assassin, a Nemesis, a Sniper and a Survivor. Thus we should have at least four players to make this mode possible ~ xWhitey
    bool bDarkHarvestMode = (bNemesisRound || bSurvivorRound || bSniperRound || bSwarmRound || bAssassinRound || bNightmareMode || bArmageddonMode || ZM_UTIL_CountPlayers() < 4) ? false : (Math.RandomLong(0, 99) < 10); //10% chance
    //Multiple Infection - added on 06/21/2024 - In this mode we have (total player count / 2) zombies. Acts like "Swarm Mode" but in Swarm you have to KILL the humanity, not infect them.
    bool bMultiInfectionMode = (bNemesisRound || bSurvivorRound || bSniperRound || bSwarmRound || bAssassinRound || bNightmareMode || bArmageddonMode || bDarkHarvestMode || ZM_UTIL_CountPlayers() < 4) ? false : (Math.RandomLong(0, 99) < 15); //15% chance
    
    if (g_bGuaranteedFirstMode && ZM_UTIL_CountPlayers() >= 4) {
        bDarkHarvestMode = true;
        
        bNemesisRound = false;
        bSurvivorRound = false;
        bSniperRound = false;
        bSwarmRound = false;
        bAssassinRound = false;
        bNightmareMode = false;
        bArmageddonMode = false;
        bMultiInfectionMode = false;
        g_bGuaranteedFirstMode = false;
    }
    
    bool bDefaultRound = (!bNemesisRound && !bSurvivorRound && !bSniperRound && !bSwarmRound && !bAssassinRound && !bNightmareMode && !bDarkHarvestMode && !bMultiInfectionMode);
    
    g_bDefaultRound = bDefaultRound;
    g_bSwarmRound = bSwarmRound;
    g_bSniperRound = bSniperRound;
    g_bSurvivorRound = bSurvivorRound;
    g_bNemesisRound = bNemesisRound;
    g_bAssassinRound = bAssassinRound;
    g_bNightmareMode = bNightmareMode;
    g_bArmageddonMode = bArmageddonMode;
    g_bDarkHarvestMode = bDarkHarvestMode;
    g_bMultiInfectionMode = bMultiInfectionMode;
    
    if (bDefaultRound) {
        string szRandomSound = g_rglpszRoundStartSounds[Math.RandomLong(0, g_rglpszRoundStartSounds.length() - 1)];
        szRandomSound = szRandomSound.SubString(0, szRandomSound.Length() - 4 /* cut .wav */);
        
        ZM_UTIL_SendSpeakSoundStuffTextMsg(szRandomSound);
    } else if (bSurvivorRound || bSniperRound) {
        string szRandomSound = g_rglpszHumanTankRoundStartSounds[Math.RandomLong(0, g_rglpszHumanTankRoundStartSounds.length() - 1)];
        szRandomSound = szRandomSound.SubString(0, szRandomSound.Length() - 4 /* cut .wav */);
        
        ZM_UTIL_SendSpeakSoundStuffTextMsg(szRandomSound);
    } else if (bNemesisRound || bSwarmRound || bAssassinRound) {
        string szRandomSound = g_rglpszNemesisRoundStartSounds[Math.RandomLong(0, g_rglpszNemesisRoundStartSounds.length() - 1)];
        szRandomSound = szRandomSound.SubString(0, szRandomSound.Length() - 4 /* cut .wav */);
        
        ZM_UTIL_SendSpeakSoundStuffTextMsg(szRandomSound);
    }
    
    if (bDefaultRound) {
        int iRandomZombie = Math.RandomLong(0, aPlayers.length() - 1);
        
        CBasePlayer@ pZombie = aPlayers[iRandomZombie];
        aPlayers.removeAt(iRandomZombie);
        
        g_ahZombies.insertLast(EHandle(pZombie));
        
        HUDTextParams params;
        params.r1 = 255;
        params.g1 = 0;
        params.b1 = 0;
        params.a1 = 160;
        params.a2 = 160;
        params.x = -1.0f;
        params.y = 0.25f;
        params.effect = 0;
        params.fadeinTime = 0.0f;
        params.fadeoutTime = 0.5f;
        params.holdTime = 2.0f;
        params.channel = 4;
        
        g_PlayerFuncs.HudMessageAll(params, string(pZombie.pev.netname) + " is the first zombie !!");
    } else if (bSwarmRound) {
        uint iRandomZombiesCount = aPlayers.length() / 2;
        for (uint idx = 0; idx < iRandomZombiesCount; idx++) {
            int iRandomZombie = Math.RandomLong(0, aPlayers.length() - 1);
        
            CBasePlayer@ pZombie = aPlayers[iRandomZombie];
            int nZombieIdx = pZombie.entindex();
            if (g_abZombies[nZombieIdx]) {
                idx--;
                continue;
            }
    
            g_abZombies[nZombieIdx] = true;
            
            g_ahZombies.insertLast(EHandle(pZombie));
        }
        
        HUDTextParams params;
        params.r1 = 0;
        params.g1 = 255;
        params.b1 = 0;
        params.a1 = 160;
        params.a2 = 160;
        params.x = -1.0f;
        params.y = 0.25f;
        params.effect = 0;
        params.fadeinTime = 0.0f;
        params.fadeoutTime = 0.5f;
        params.holdTime = 2.0f;
        params.channel = 4;
        
        g_PlayerFuncs.HudMessageAll(params, "Swarm Mode !!!");
    } else if (bSurvivorRound) {
        uint iRandomSurvivor = uint(Math.RandomLong(0, aPlayers.length() - 1));
        
        CBasePlayer@ pSurvivor = aPlayers[iRandomSurvivor];
        for (uint idx = 0; idx < aPlayers.length(); idx++) {
            if (idx == iRandomSurvivor) continue;
            CBasePlayer@ pZombie = aPlayers[idx];
            g_ahZombies.insertLast(EHandle(pZombie));
        }
        g_ahHumanTanks.insertLast(EHandle(pSurvivor));
        pSurvivor.RemoveAllItems(false);
        pSurvivor.GiveNamedItem("weapon_m249", 0, 1);
        pSurvivor.pev.max_health = 2000.f;
        pSurvivor.pev.health = 2000.f;
        g_abIsSurvivor[pSurvivor.entindex()] = true;
        
        HUDTextParams params;
        params.r1 = 0;
        params.g1 = 0;
        params.b1 = 255;
        params.a1 = 160;
        params.a2 = 160;
        params.x = -1.0f;
        params.y = 0.25f;
        params.effect = 0;
        params.fadeinTime = 0.0f;
        params.fadeoutTime = 0.5f;
        params.holdTime = 2.0f;
        params.channel = 4;

        CBackupFrostNadePlayerData@ pBackupData = CBackupFrostNadePlayerData();
        pBackupData.m_iRenderMode = pSurvivor.pev.rendermode;
        pBackupData.m_flRenderAmount = pSurvivor.pev.renderamt;
        pBackupData.m_vecRenderColor = pSurvivor.pev.rendercolor;
        pBackupData.m_iRenderFX = pSurvivor.pev.renderfx;
        @g_rglpBackupHumanTanksPlayerData[pSurvivor.entindex()] = @pBackupData;
        
        g_PlayerFuncs.HudMessageAll(params, string(pSurvivor.pev.netname) + " is Survivor !!!");
    } else if (bSniperRound) {
        uint iRandomSurvivor = uint(Math.RandomLong(0, aPlayers.length() - 1));
        
        CBasePlayer@ pSurvivor = aPlayers[iRandomSurvivor];
        for (uint idx = 0; idx < aPlayers.length(); idx++) {
            if (idx == iRandomSurvivor) continue;
            CBasePlayer@ pZombie = aPlayers[idx];
            g_ahZombies.insertLast(EHandle(pZombie));
        }
        g_ahHumanTanks.insertLast(EHandle(pSurvivor));
        pSurvivor.RemoveAllItems(false);
        pSurvivor.GiveNamedItem("weapon_sniperrifle", 0, 1);
        pSurvivor.pev.max_health = 2000.f;
        pSurvivor.pev.health = 2000.f;
        g_abIsSniper[pSurvivor.entindex()] = true;
        
        HUDTextParams params;
        params.r1 = 0;
        params.g1 = 255;
        params.b1 = 0;
        params.a1 = 160;
        params.a2 = 160;
        params.x = -1.0f;
        params.y = 0.25f;
        params.effect = 0;
        params.fadeinTime = 0.0f;
        params.fadeoutTime = 0.5f;
        params.holdTime = 2.0f;
        params.channel = 4;
        
        CBackupFrostNadePlayerData@ pBackupData = CBackupFrostNadePlayerData();
        pBackupData.m_iRenderMode = pSurvivor.pev.rendermode;
        pBackupData.m_flRenderAmount = pSurvivor.pev.renderamt;
        pBackupData.m_vecRenderColor = pSurvivor.pev.rendercolor;
        pBackupData.m_iRenderFX = pSurvivor.pev.renderfx;
        @g_rglpBackupHumanTanksPlayerData[pSurvivor.entindex()] = @pBackupData;
        
        g_PlayerFuncs.HudMessageAll(params, string(pSurvivor.pev.netname) + " is Sniper !!!");
    } else if (bNemesisRound) {
        int iRandomZombie = Math.RandomLong(0, aPlayers.length() - 1);
        
        CBasePlayer@ pZombie = aPlayers[iRandomZombie];
        aPlayers.removeAt(iRandomZombie);
        
        g_ahZombies.insertLast(EHandle(pZombie));
        g_abIsNemesis[pZombie.entindex()] = true;
        g_ahNemesises.insertLast(EHandle(pZombie));
        
        string szSteamID = g_EngineFuncs.GetPlayerAuthId(pZombie.edict());
        CPlayerData@ pData = ZM_UTIL_GetPlayerDataBySteamID(szSteamID);
        if (pData is null) {
            @pData = CPlayerData(szSteamID);
            g_rglpPlayerDatas.insertLast(pData);
        }
        @pData.m_lpBackupZombieClass = @pData.m_lpZombieClass;
        @pData.m_lpZombieClass = ZM_UTIL_FindZombieClassByName("Nemesis");
        
        HUDTextParams params;
        params.r1 = 255;
        params.g1 = 255;
        params.b1 = 0;
        params.a1 = 160;
        params.a2 = 160;
        params.x = -1.0f;
        params.y = 0.25f;
        params.effect = 0;
        params.fadeinTime = 0.0f;
        params.fadeoutTime = 0.5f;
        params.holdTime = 2.0f;
        params.channel = 4;
        
        CBackupFrostNadePlayerData@ pBackupData = CBackupFrostNadePlayerData();
        pBackupData.m_iRenderMode = pZombie.pev.rendermode;
        pBackupData.m_flRenderAmount = pZombie.pev.renderamt;
        pBackupData.m_vecRenderColor = pZombie.pev.rendercolor;
        pBackupData.m_iRenderFX = pZombie.pev.renderfx;
        @g_rglpBackupAssassinPlayerData[pZombie.entindex()] = @pBackupData;
        
        g_PlayerFuncs.HudMessageAll(params, string(pZombie.pev.netname) + " is Nemesis !!");
    } else if (bAssassinRound) {
        int iRandomZombie = Math.RandomLong(0, aPlayers.length() - 1);
        
        CBasePlayer@ pZombie = aPlayers[iRandomZombie];
        aPlayers.removeAt(iRandomZombie);
        
        g_ahZombies.insertLast(EHandle(pZombie));
        g_abIsAssassin[pZombie.entindex()] = true;
        g_ahAssassins.insertLast(EHandle(pZombie));
        
        string szSteamID = g_EngineFuncs.GetPlayerAuthId(pZombie.edict());
        CPlayerData@ pData = ZM_UTIL_GetPlayerDataBySteamID(szSteamID);
        if (pData is null) {
            @pData = CPlayerData(szSteamID);
            g_rglpPlayerDatas.insertLast(pData);
        }
        @pData.m_lpBackupZombieClass = @pData.m_lpZombieClass;
        @pData.m_lpZombieClass = ZM_UTIL_FindZombieClassByName("Assassin");
        
        HUDTextParams params;
        params.r1 = 255;
        params.g1 = 0;
        params.b1 = 0;
        params.a1 = 160;
        params.a2 = 160;
        params.x = -1.0f;
        params.y = 0.25f;
        params.effect = 0;
        params.fadeinTime = 0.0f;
        params.fadeoutTime = 0.5f;
        params.holdTime = 2.0f;
        params.channel = 4;
        
        CBackupFrostNadePlayerData@ pBackupData = CBackupFrostNadePlayerData();
        pBackupData.m_iRenderMode = pZombie.pev.rendermode;
        pBackupData.m_flRenderAmount = pZombie.pev.renderamt;
        pBackupData.m_vecRenderColor = pZombie.pev.rendercolor;
        pBackupData.m_iRenderFX = pZombie.pev.renderfx;
        @g_rglpBackupAssassinPlayerData[pZombie.entindex()] = @pBackupData;
        
        g_EngineFuncs.LightStyle(0 , "a");
        
        g_PlayerFuncs.HudMessageAll(params, string(pZombie.pev.netname) + " is Assassin !!!");
    } else if (bNightmareMode) {
        uint iMaxZombies = aPlayers.length() / 2;
        uint nCurrentZombiesCount = 0;
        for (uint idx = 0; idx < iMaxZombies; idx++) {
            int iRandomZombie = Math.RandomLong(0, aPlayers.length() - 1);
            CBasePlayer@ pZombie = aPlayers[iRandomZombie];
            int nZombieIdx = pZombie.entindex();
            if (g_abZombies[nZombieIdx]) {
                idx--;
                continue;
            }
            
            CBackupFrostNadePlayerData@ pBackupData = CBackupFrostNadePlayerData();
            pBackupData.m_iRenderMode = pZombie.pev.rendermode;
            pBackupData.m_flRenderAmount = pZombie.pev.renderamt;
            pBackupData.m_vecRenderColor = pZombie.pev.rendercolor;
            pBackupData.m_iRenderFX = pZombie.pev.renderfx;
            @g_rglpBackupAssassinPlayerData[pZombie.entindex()] = @pBackupData;
            if (Math.RandomLong(0, 99) % 2 == 0) /* Nemesis */ {
                g_abZombies[nZombieIdx] = true;
                g_abIsNemesis[nZombieIdx] = true;
                g_ahNemesises.insertLast(EHandle(pZombie));
                
                string szSteamID = g_EngineFuncs.GetPlayerAuthId(pZombie.edict());
                CPlayerData@ pData = ZM_UTIL_GetPlayerDataBySteamID(szSteamID);
                if (pData is null) {
                    @pData = CPlayerData(szSteamID);
                    g_rglpPlayerDatas.insertLast(pData);
                }
                @pData.m_lpBackupZombieClass = @pData.m_lpZombieClass;
                @pData.m_lpZombieClass = ZM_UTIL_FindZombieClassByName("Nemesis");
                
                g_ahZombies.insertLast(EHandle(pZombie));
            } else /* Assassin */ {
                g_abZombies[nZombieIdx] = true;
                g_abIsAssassin[nZombieIdx] = true;
                g_ahAssassins.insertLast(EHandle(pZombie));
                
                string szSteamID = g_EngineFuncs.GetPlayerAuthId(pZombie.edict());
                CPlayerData@ pData = ZM_UTIL_GetPlayerDataBySteamID(szSteamID);
                if (pData is null) {
                    @pData = CPlayerData(szSteamID);
                    g_rglpPlayerDatas.insertLast(pData);
                }
                @pData.m_lpBackupZombieClass = @pData.m_lpZombieClass;
                @pData.m_lpZombieClass = ZM_UTIL_FindZombieClassByName("Assassin");
                
                g_ahZombies.insertLast(EHandle(pZombie));
            }
        }
    
        for (uint idx = 0; idx < aPlayers.length(); idx++) {
            CBasePlayer@ pPlayer = aPlayers[idx];
            if (g_abZombies[pPlayer.entindex()]) continue;
            g_ahHumanTanks.insertLast(EHandle(pPlayer));
            pPlayer.pev.max_health = 2000.f;
            pPlayer.pev.health = 2000.f;
            pPlayer.RemoveAllItems(false);
            CBackupFrostNadePlayerData@ pBackupData = CBackupFrostNadePlayerData();
            pBackupData.m_iRenderMode = pPlayer.pev.rendermode;
            pBackupData.m_flRenderAmount = pPlayer.pev.renderamt;
            pBackupData.m_vecRenderColor = pPlayer.pev.rendercolor;
            pBackupData.m_iRenderFX = pPlayer.pev.renderfx;
            @g_rglpBackupHumanTanksPlayerData[pPlayer.entindex()] = @pBackupData;
            if (Math.RandomLong(0, 99) % 2 == 0) /* Sniper */ {
                pPlayer.GiveNamedItem("weapon_sniperrifle", 0, 1);
                g_abIsSniper[pPlayer.entindex()] = true;
            } else /* Survivor */ {
                pPlayer.GiveNamedItem("weapon_m249", 0, 1);
                g_abIsSurvivor[pPlayer.entindex()] = true;
            }
        }
        
        HUDTextParams params;
        params.r1 = 255;
        params.g1 = 0;
        params.b1 = 255;
        params.a1 = 160;
        params.a2 = 160;
        params.x = -1.0f;
        params.y = 0.25f;
        params.effect = 0;
        params.fadeinTime = 0.0f;
        params.fadeoutTime = 0.5f;
        params.holdTime = 2.0f;
        params.channel = 4;
        
        g_EngineFuncs.LightStyle(0 , "a");
        
        g_PlayerFuncs.HudMessageAll(params, "Nightfall Mode !!!");
    } else if (bArmageddonMode) {
        uint iMaxZombies = aPlayers.length() / 2;
        uint nCurrentZombiesCount = 0;
        for (uint idx = 0; idx < iMaxZombies; idx++) {
            int iRandomZombie = Math.RandomLong(0, aPlayers.length() - 1);
            CBasePlayer@ pZombie = aPlayers[iRandomZombie];
            int nZombieIdx = pZombie.entindex();
            if (g_abZombies[nZombieIdx]) {
                idx--;
                continue;
            }
            
            CBackupFrostNadePlayerData@ pBackupData = CBackupFrostNadePlayerData();
            pBackupData.m_iRenderMode = pZombie.pev.rendermode;
            pBackupData.m_flRenderAmount = pZombie.pev.renderamt;
            pBackupData.m_vecRenderColor = pZombie.pev.rendercolor;
            pBackupData.m_iRenderFX = pZombie.pev.renderfx;
            @g_rglpBackupAssassinPlayerData[pZombie.entindex()] = @pBackupData;
            g_abZombies[nZombieIdx] = true;
            g_abIsNemesis[nZombieIdx] = true;
            g_ahNemesises.insertLast(EHandle(pZombie));
                
            string szSteamID = g_EngineFuncs.GetPlayerAuthId(pZombie.edict());
            CPlayerData@ pData = ZM_UTIL_GetPlayerDataBySteamID(szSteamID);
            if (pData is null) {
                @pData = CPlayerData(szSteamID);
                g_rglpPlayerDatas.insertLast(pData);
            }
            @pData.m_lpBackupZombieClass = @pData.m_lpZombieClass;
            @pData.m_lpZombieClass = ZM_UTIL_FindZombieClassByName("Nemesis");
                
            g_ahZombies.insertLast(EHandle(pZombie));
        }
    
        for (uint idx = 0; idx < aPlayers.length(); idx++) {
            CBasePlayer@ pPlayer = aPlayers[idx];
            if (g_abZombies[pPlayer.entindex()]) continue;
            g_ahHumanTanks.insertLast(EHandle(pPlayer));
            pPlayer.pev.max_health = 2000.f;
            pPlayer.pev.health = 2000.f;
            pPlayer.RemoveAllItems(false);
            CBackupFrostNadePlayerData@ pBackupData = CBackupFrostNadePlayerData();
            pBackupData.m_iRenderMode = pPlayer.pev.rendermode;
            pBackupData.m_flRenderAmount = pPlayer.pev.renderamt;
            pBackupData.m_vecRenderColor = pPlayer.pev.rendercolor;
            pBackupData.m_iRenderFX = pPlayer.pev.renderfx;
            @g_rglpBackupHumanTanksPlayerData[pPlayer.entindex()] = @pBackupData;
            pPlayer.GiveNamedItem("weapon_m249", 0, 1);
        }
        
        HUDTextParams params;
        params.r1 = 255;
        params.g1 = 0;
        params.b1 = 255;
        params.a1 = 160;
        params.a2 = 160;
        params.x = -1.0f;
        params.y = 0.25f;
        params.effect = 0;
        params.fadeinTime = 0.0f;
        params.fadeoutTime = 0.5f;
        params.holdTime = 2.0f;
        params.channel = 4;
        
        g_PlayerFuncs.HudMessageAll(params, "Hellscape Mode !!!");
    } else if (bDarkHarvestMode) {
        uint nCurrentZombiesCount = 0;
        for (uint idx = 0; idx < 2; idx++) {
            int iRandomZombie = Math.RandomLong(0, aPlayers.length() - 1);
            CBasePlayer@ pZombie = aPlayers[iRandomZombie];
            int nZombieIdx = pZombie.entindex();
            if (g_abZombies[nZombieIdx]) {
                idx--;
                continue;
            }
            
            CBackupFrostNadePlayerData@ pBackupData = CBackupFrostNadePlayerData();
            pBackupData.m_iRenderMode = pZombie.pev.rendermode;
            pBackupData.m_flRenderAmount = pZombie.pev.renderamt;
            pBackupData.m_vecRenderColor = pZombie.pev.rendercolor;
            pBackupData.m_iRenderFX = pZombie.pev.renderfx;
            @g_rglpBackupAssassinPlayerData[pZombie.entindex()] = @pBackupData;
            if (idx == 0) /* Nemesis */ {
                g_abZombies[nZombieIdx] = true;
                g_abIsNemesis[nZombieIdx] = true;
                g_ahNemesises.insertLast(EHandle(pZombie));
                
                string szSteamID = g_EngineFuncs.GetPlayerAuthId(pZombie.edict());
                CPlayerData@ pData = ZM_UTIL_GetPlayerDataBySteamID(szSteamID);
                if (pData is null) {
                    @pData = CPlayerData(szSteamID);
                    g_rglpPlayerDatas.insertLast(pData);
                }
                @pData.m_lpBackupZombieClass = @pData.m_lpZombieClass;
                @pData.m_lpZombieClass = ZM_UTIL_FindZombieClassByName("Nemesis");
                
                g_ahZombies.insertLast(EHandle(pZombie));
            } else /* Assassin */ {
                g_abZombies[nZombieIdx] = true;
                g_abIsAssassin[nZombieIdx] = true;
                g_ahAssassins.insertLast(EHandle(pZombie));
                
                string szSteamID = g_EngineFuncs.GetPlayerAuthId(pZombie.edict());
                CPlayerData@ pData = ZM_UTIL_GetPlayerDataBySteamID(szSteamID);
                if (pData is null) {
                    @pData = CPlayerData(szSteamID);
                    g_rglpPlayerDatas.insertLast(pData);
                }
                @pData.m_lpBackupZombieClass = @pData.m_lpZombieClass;
                @pData.m_lpZombieClass = ZM_UTIL_FindZombieClassByName("Assassin");
                
                g_ahZombies.insertLast(EHandle(pZombie));
            }
        }
    
        for (uint idx = 0; idx < 2; idx++) {
            int iRandomHumanTank = Math.RandomLong(0, aPlayers.length() - 1);
            CBasePlayer@ pPlayer = aPlayers[iRandomHumanTank];
            if (g_abZombies[pPlayer.entindex()] || g_abIsSniper[pPlayer.entindex()] || g_abIsSurvivor[pPlayer.entindex()] || ZM_UTIL_IsPlayerAHumanTank(g_EngineFuncs.GetPlayerAuthId(pPlayer.edict()))) {
                idx--;
                continue;
            }
            g_ahHumanTanks.insertLast(EHandle(pPlayer));
            pPlayer.pev.max_health = 2000.f;
            pPlayer.pev.health = 2000.f;
            pPlayer.RemoveAllItems(false);
            CBackupFrostNadePlayerData@ pBackupData = CBackupFrostNadePlayerData();
            pBackupData.m_iRenderMode = pPlayer.pev.rendermode;
            pBackupData.m_flRenderAmount = pPlayer.pev.renderamt;
            pBackupData.m_vecRenderColor = pPlayer.pev.rendercolor;
            pBackupData.m_iRenderFX = pPlayer.pev.renderfx;
            @g_rglpBackupHumanTanksPlayerData[pPlayer.entindex()] = @pBackupData;
            if (idx == 0) /* Sniper */ {
                pPlayer.GiveNamedItem("weapon_sniperrifle", 0, 1);
                g_abIsSniper[pPlayer.entindex()] = true;
            } else /* Survivor */ {
                pPlayer.GiveNamedItem("weapon_m249", 0, 1);
                g_abIsSurvivor[pPlayer.entindex()] = true;
            }
        }
        
        HUDTextParams params;
        params.r1 = 255;
        params.g1 = 0;
        params.b1 = 255;
        params.a1 = 160;
        params.a2 = 160;
        params.x = -1.0f;
        params.y = 0.25f;
        params.effect = 0;
        params.fadeinTime = 0.0f;
        params.fadeoutTime = 0.5f;
        params.holdTime = 2.0f;
        params.channel = 4;
        
        g_PlayerFuncs.HudMessageAll(params, "Dark Harvest Mode !!!");
    } else if (bMultiInfectionMode) {
        uint iRandomZombiesCount = aPlayers.length() / 2;
        for (uint idx = 0; idx < iRandomZombiesCount; idx++) {
            int iRandomZombie = Math.RandomLong(0, aPlayers.length() - 1);
        
            CBasePlayer@ pZombie = aPlayers[iRandomZombie];
            int nZombieIdx = pZombie.entindex();
            if (g_abZombies[nZombieIdx]) {
                idx--;
                continue;
            }
    
            g_abZombies[nZombieIdx] = true;
            
            g_ahZombies.insertLast(EHandle(pZombie));
        }
        
        HUDTextParams params;
        params.r1 = 0;
        params.g1 = 255;
        params.b1 = 0;
        params.a1 = 160;
        params.a2 = 160;
        params.x = -1.0f;
        params.y = 0.25f;
        params.effect = 0;
        params.fadeinTime = 0.0f;
        params.fadeoutTime = 0.5f;
        params.holdTime = 2.0f;
        params.channel = 4;
        
        g_PlayerFuncs.HudMessageAll(params, "Multiple Infection !!!");
    }
    
    @g_lpfnMakeHumanTanksShiny = g_Scheduler.SetTimeout("MakeHumanTanksShiny", 0.1f);
    @g_lpfnMakeAssassinShiny = g_Scheduler.SetTimeout("MakeAssassinShiny", 0.1f);
    
    //bool bChangedSky = false;
    
    for (uint idx = 0; idx < g_ahZombies.length(); idx++) {
        EHandle hZombie = g_ahZombies[idx];
        if (!hZombie.IsValid()) continue;
        CBasePlayer@ pPlayer = cast<CBasePlayer@>(hZombie.GetEntity());
        
        //Yes. This used to work like this. It used to change the sky upon the first round start, very old thingy. Thanks to ScriptedSnark for showing me how to replace the skybox properly.
        //if (!bChangedSky) {
        //    CBaseEntity@ lpChanger = g_EntityFuncs.Create("trigger_changesky", g_vecZero, g_vecZero, true, null);
        //    g_EntityFuncs.DispatchKeyValue(lpChanger.edict(), "skyname", "night");
        //    g_EntityFuncs.DispatchKeyValue(lpChanger.edict(), "flags", 1 /* All players */);
        //    g_EntityFuncs.DispatchSpawn(lpChanger.edict());
        //    lpChanger.Use(pPlayer, pPlayer, USE_TOGGLE);
        //    bChangedSky = true;
        //}
        
        ZM_UTIL_TurnPlayerIntoAZombie(pPlayer);
        if (!g_bSwarmRound) {
            pPlayer.pev.health *= 2.f;
            pPlayer.pev.max_health *= 2.f;
        }
    }
    
    @g_lpfnForceZombieModels = g_Scheduler.SetTimeout("ForceZombieModels", 0.0f);
    @g_lpfnUpdateTimer = g_Scheduler.SetTimeout("UpdateTimer", 0.0f);
    @g_lpfnSafety = g_Scheduler.SetTimeout("Safety", 0.0f);
    @g_lpfnRemovePipeWrenchesFromNonEngineers = g_Scheduler.SetTimeout("RemovePipeWrenchesFromNonEngineers", 0.5f);
}

Vector g_vecNightVisionColour(65, 245, 245);

void ForceZombieModels() {
    if (!g_bMatchStarted) return;
    for (uint idx = 0; idx < g_ahZombies.length(); idx++) {
        EHandle hZombie = g_ahZombies[idx];
        if (!hZombie.IsValid()) {
            g_ahZombies.removeAt(idx);
            continue;
        }
        CBasePlayer@ pPlayer = cast<CBasePlayer@>(hZombie.GetEntity());
        if (!pPlayer.IsAlive() || !pPlayer.IsConnected()) {
            g_ahZombies.removeAt(idx);
            continue;
        }
        //g_PlayerFuncs.ScreenFade(pPlayer, g_vecNightVisionColour, 0.01, 0.5, 64, FFADE_OUT | FFADE_STAYOUT);
        if (g_abZombieTrickyNightVision[pPlayer.entindex()]) {
            pPlayer.pev.effects &= ~EF_DIMLIGHT;
            pPlayer.m_iFlashBattery = 100;
            Vector vecSrc = pPlayer.EyePosition();
            NetworkMessage nvon(MSG_ONE, NetworkMessages::SVC_TEMPENTITY, pPlayer.edict());
                nvon.WriteByte(TE_DLIGHT);
                nvon.WriteCoord(vecSrc.x);
                nvon.WriteCoord(vecSrc.y);
                nvon.WriteCoord(vecSrc.z);
                nvon.WriteByte(40);
                nvon.WriteByte(int(g_vecNightVisionColour.x));
                nvon.WriteByte(int(g_vecNightVisionColour.y));
                nvon.WriteByte(int(g_vecNightVisionColour.z));
                nvon.WriteByte(2);
                nvon.WriteByte(1);
            nvon.End();
        }
        string szSteamID = g_EngineFuncs.GetPlayerAuthId(pPlayer.edict());
        CPlayerData@ pData = ZM_UTIL_GetPlayerDataBySteamID(szSteamID);
        if (pData !is null) {
            pPlayer.SetOverriddenPlayerModel(pData.m_lpZombieClass.m_lpszPlayerModel);
        }
    }
    if (g_ahZombies.length() == 0) {
        MatchEnd();
    } else {
        @g_lpfnForceZombieModels = g_Scheduler.SetTimeout("ForceZombieModels", 0.1f);
    }
}

void MatchCleanup() {
    g_EngineFuncs.LightStyle(0 , "c");
    g_ahZombies.resize(0);
    g_ahHumanTanks.resize(0);
    g_ahAssassins.resize(0);
    g_ahNemesises.resize(0);
    g_rgflLastZombieSentenceTime.resize(0);
    g_rgflLastZombieSentenceTime.resize(33);
    g_abZombies.resize(0);
    g_abZombies.resize(33);
    g_abIsSniper.resize(0);
    g_abIsSniper.resize(33);
    g_abIsSurvivor.resize(0);
    g_abIsSurvivor.resize(33);
    g_aiZombieBurnDuration.resize(0);
    g_aiZombieBurnDuration.resize(33);
    for (uint idx = 0; idx < g_rglpfnBurningLoops.length(); idx++) {
        CScheduledFunction@ pSched = g_rglpfnBurningLoops[idx];
        if (pSched !is null && pSched.HasBeenRemoved()) {
            g_Scheduler.RemoveTimer(pSched);
        }
    }
    g_rglpfnBurningLoops.resize(0);
    g_rglpfnBurningLoops.resize(33);
    for (uint idx = 0; idx < g_rglpfnFrozenLoops.length(); idx++) {
        CScheduledFunction@ pSched = g_rglpfnFrozenLoops[idx];
        if (pSched !is null && pSched.HasBeenRemoved()) {
            g_Scheduler.RemoveTimer(pSched);
        }
    }
    g_rglpfnFrozenLoops.resize(0);
    g_rglpfnFrozenLoops.resize(33);
    g_abIsZombieFrozen.resize(0);
    g_abIsZombieFrozen.resize(33);
    g_abIsNemesis.resize(0);
    g_abIsNemesis.resize(33);
    g_abIsAssassin.resize(0);
    g_abIsAssassin.resize(33);
    g_rglpBackupFrostNadePlayerData.resize(0);
    g_rglpBackupFrostNadePlayerData.resize(33);
    for (uint idx = 0; idx < g_rglpfnUnfreezeScheds.length(); idx++) {
        CScheduledFunction@ pSched = g_rglpfnUnfreezeScheds[idx];
        if (pSched !is null && pSched.HasBeenRemoved()) {
            g_Scheduler.RemoveTimer(pSched);
        }
    }
    g_rglpfnUnfreezeScheds.resize(0);
    g_rglpfnUnfreezeScheds.resize(33);
    g_abCarriesNightvision.resize(0);
    g_abCarriesNightvision.resize(33);
    g_aapBoughtArms.resize(0);
    g_aapBoughtArms.resize(33);
    g_abHasBoughtInfiniteAmmo.resize(0);
    g_abHasBoughtInfiniteAmmo.resize(33);
    g_rgiWrenchHitCount.resize(0);
    g_rgiWrenchHitCount.resize(33);
    g_abZombieTrickyNightVision.resize(0);
    g_abZombieTrickyNightVision.resize(33);
    g_abSpectatorTrickyNightVision.resize(0);
    g_abSpectatorTrickyNightVision.resize(33);
    g_rgflLastSpectatorNightVisionUpdateTime.resize(0);
    g_rgflLastSpectatorNightVisionUpdateTime.resize(33);
    
    @g_lpfnResetPlayerStates = g_Scheduler.SetTimeout("ResetPlayerStates", 0.5f);
    for (uint idx = 0; idx < g_rglpPlayerDatas.length(); idx++) {
        CPlayerData@ pData = g_rglpPlayerDatas[idx];
        pData.m_bHasGotFirstWeapon = false;
        pData.m_bHasGotSecondaryWeapon = false;
        if (pData.m_lpBackupZombieClass is null)
            continue;
        @pData.m_lpZombieClass = @pData.m_lpBackupZombieClass;
        @pData.m_lpBackupZombieClass = null;
    }
}

void ResetPlayerStates() {
    for (int idx = 1; idx <= g_Engine.maxClients; idx++) {
        CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(idx);
        if (pPlayer !is null && pPlayer.IsConnected()) {
            pPlayer.RemoveAllItems(false);
            pPlayer.SetClassification(2); //CLASS_PLAYER
            pPlayer.SendScoreInfo();
            pPlayer.pev.max_health = 100;
            pPlayer.pev.gravity = 1.0f;
            pPlayer.pev.maxspeed = 270.f;
            string szSteamID = g_EngineFuncs.GetPlayerAuthId(pPlayer.edict());
            CPlayerData@ pData = ZM_UTIL_GetPlayerDataBySteamID(szSteamID);
            if (pData is null) continue;
            pPlayer.SetOverriddenPlayerModel(pData.m_lpszBackupModel);
            //g_PlayerFuncs.ScreenFade(pPlayer, g_vecNightVisionColour, 0.01, 0.1, 64, FFADE_IN);
        }
    }
}

void RemovePipeWrenchesFromNonEngineers() {
    for (int idx = 1; idx <= g_Engine.maxClients; idx++) {
        CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(idx);
        if (pPlayer !is null && pPlayer.IsConnected() && pPlayer.IsAlive()) {
            CBasePlayerItem@ pItem;
            bool bDone = false;
            for (uint j = 0; j < 2; j++) {
                if (bDone) break;
                @pItem = pPlayer.m_rgpPlayerItems(j);
                while (pItem !is null) {
                    if (pItem.GetClassname() == "weapon_pipewrench") {
                        CPlayerData@ pData = ZM_UTIL_GetPlayerDataBySteamID(g_EngineFuncs.GetPlayerAuthId(pPlayer.edict()));
                        if (pData.m_lpHumanClass.m_lpszName != "Engineer") {
                            pPlayer.RemovePlayerItem(pItem);
                        }
                        if (g_rgiWrenchHitCount[pPlayer.entindex()] > 15) {
                            pPlayer.RemovePlayerItem(pItem);
                            g_PlayerFuncs.SayText(pPlayer, "[ZP] Your wrench broke!\n");
                        }
                        bDone = true;
                        break;
                    }
                                
                    @pItem = cast<CBasePlayerItem@>(pItem.m_hNextItem.GetEntity());
                }
            }
        }
    }
    
    if (g_bMatchStarted)
        @g_lpfnRemovePipeWrenchesFromNonEngineers = g_Scheduler.SetTimeout("RemovePipeWrenchesFromNonEngineers", 1.0f);
}

void Safety() {
    if (ZM_UTIL_CountAlivePlayers() == 0 || g_ahZombies.length() == 0)
        MatchEnd();
    
    if (g_bMatchStarted)
        @g_lpfnSafety = g_Scheduler.SetTimeout("Safety", 0.2f);
}

void MatchEnd() {
    if (!g_bMatchStarted) return;
    
    for (int idx = 0; idx < g_Engine.maxEntities; idx++) {
        CBaseEntity@ pEntity = g_EntityFuncs.Instance(idx);
        if (pEntity !is null and pEntity.pev !is null) {
            string szClassname = string(pEntity.pev.classname);
            if (szClassname == "weaponbox" || szClassname.Find("weapon_") == 0 || szClassname.Find("ammo_") == 0 || szClassname.Find("item_") == 0 || szClassname.Find("zpc_smokenade") == 0 || szClassname.Find("zpc_firenade") == 0 || szClassname.Find("zpc_frostnade") == 0) {
                if (szClassname == "item_generic") continue;
                g_EntityFuncs.Remove(pEntity);
            }
        }
    }
    
    g_bMatchStarted = false;
    g_bDefaultRound = false;
    g_bSwarmRound = false;
    g_bSniperRound = false;
    g_bSurvivorRound = false;
    g_bNemesisRound = false;
    g_bAssassinRound = false;
    g_bNightmareMode = false;
    g_bArmageddonMode = false;
    g_bDarkHarvestMode = false;
    g_bMultiInfectionMode = false;

    if (ZM_UTIL_CountAlivePlayers() == 0) {
        HUDTextParams params;
        params.r1 = 255;
        params.g1 = 0;
        params.b1 = 0;
        params.a1 = 160;
        params.a2 = 160;
        params.x = -1.0f;
        params.y = 0.25f;
        params.effect = 0;
        params.fadeinTime = 0.5f;
        params.fadeoutTime = 0.5f;
        params.holdTime = 3.0f;
        params.channel = 3;
        
        g_PlayerFuncs.HudMessageAll(params, "Zombies have taken over the world!");
        
        string szRandomSound = g_rglpszZombiesWinSounds[Math.RandomLong(0, g_rglpszZombiesWinSounds.length() - 1)];
        szRandomSound = szRandomSound.SubString(0, szRandomSound.Length() - 4 /* cut .wav */);
        
        ZM_UTIL_SendSpeakSoundStuffTextMsg(szRandomSound);
    } else {
        HUDTextParams params;
        params.r1 = 0;
        params.g1 = 60;
        params.b1 = 255;
        params.a1 = 160;
        params.a2 = 160;
        params.x = -1.0f;
        params.y = 0.25f;
        params.effect = 0;
        params.fadeinTime = 0.5f;
        params.fadeoutTime = 0.5f;
        params.holdTime = 3.0f;
        params.channel = 3;
        
        g_PlayerFuncs.HudMessageAll(params, "Humans defeated the plague!");
        
        if (Math.RandomLong(0, 50) % 2 == 0) {
            ZM_UTIL_SendSpeakSoundStuffTextMsg("zombie_plague/win_humans1");
        } else {
            ZM_UTIL_SendSpeakSoundStuffTextMsg("zombie_plague/win_humans2");
        }
    }
    
    @g_lpfnMatchCleanup = g_Scheduler.SetTimeout("MatchCleanup", 14.5f);
    @g_lpfnRespawnPlayers = g_Scheduler.SetTimeout("RespawnPlayers", 15.0f, true);
    @g_lpfnPreMatchStart = g_Scheduler.SetTimeout("PreMatchStart", 15.0f);
}

void RespawnPlayers(bool _ResetPosition) {
    if (!g_bIsZM) return;
    if (g_bMatchStarted) return;

    for (int idx = 1; idx <= g_Engine.maxClients; idx++) {
        CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(idx);
        if (pPlayer !is null && pPlayer.IsConnected()) {
            if (_ResetPosition) {
                pPlayer.pev.health = 0;
                pPlayer.pev.max_health = 100;
                pPlayer.pev.health = 100;
                pPlayer.pev.armorvalue = 0;
                pPlayer.pev.gravity = 1.0f;
                pPlayer.pev.maxspeed = 270.f;
                g_PlayerFuncs.RespawnPlayer(pPlayer, true, true);
            }
            if (!pPlayer.IsAlive()) {
                g_PlayerFuncs.RespawnPlayer(pPlayer, true, true);
                int nPlayerIdx = pPlayer.entindex();
                CPlayerData@ pData = g_rglpFastPlayerDataAccessor[nPlayerIdx];
                if (pData is null) {
                    string szSteamID = g_EngineFuncs.GetPlayerAuthId(pPlayer.edict());
                    @pData = ZM_UTIL_GetPlayerDataBySteamID(szSteamID);
                    if (pData is null) {
                        @pData = CPlayerData(szSteamID);
                        g_rglpPlayerDatas.insertLast(@pData);
                    }
                    @g_rglpFastPlayerDataAccessor[nPlayerIdx] = @pData;
                }
                pData.m_bHasGotFirstWeapon = false;
                pData.m_bHasGotSecondaryWeapon = false;
                pPlayer.pev.health = pData.m_lpHumanClass.m_flHealth;
                pPlayer.pev.max_health = pData.m_lpHumanClass.m_flHealth;
                pPlayer.pev.armorvalue = pData.m_lpHumanClass.m_flArmour;
                if (pData.m_lpHumanClass.m_lpszName == "Engineer") {
                    CBaseEntity@ lpWeapon = g_EntityFuncs.Create("weapon_pipewrench", g_vecZero, g_vecZero, true, null);
                    lpWeapon.pev.spawnflags |= (SF_NORESPAWN | SF_CREATEDWEAPON);
                    g_EntityFuncs.DispatchSpawn(lpWeapon.edict());
                    lpWeapon.Touch(pPlayer);
                }
                pPlayer.GiveNamedItem("weapon_frostgrenade", 0, 1);
                pPlayer.GiveNamedItem("weapon_flaregrenade", 0, 1);
                pPlayer.GiveNamedItem("weapon_firegrenade", 0, 1);
                
                CBasePlayerItem@ pItem;
                CBasePlayerWeapon@ pWeapon;
                for (uint j = 0; j < 10; j++) {
                    @pItem = pPlayer.m_rgpPlayerItems(j);
                    while (pItem !is null) {
                        @pWeapon = pItem.GetWeaponPtr();
                                
                        if (pWeapon.GetClassname().Find("grenade") != String::INVALID_INDEX) {
                            int iPrimaryIdx = pWeapon.PrimaryAmmoIndex();
                            if (iPrimaryIdx != -1) {
                                pPlayer.m_rgAmmo(iPrimaryIdx, 1);
                            }
                        }
                                
                        @pItem = cast<CBasePlayerItem@>(pItem.m_hNextItem.GetEntity());
                    }
                }
            }
        }
    }
    
    @g_lpfnRespawnPlayers = g_Scheduler.SetTimeout("RespawnPlayers", 0.1f, false);
}

Vector g_vecRedColour(255, 0, 0);
Vector g_vecGreenColour(0, 255, 0);
Vector g_vecBlueColour(0, 0, 255);
Vector g_vecYellowColour(255, 255, 0);
Vector g_vecMagentaColour(255, 0, 255);

void MakeAssassinShiny() {
    if (!g_bMatchStarted) {
        for (uint idx = 0; idx < g_ahAssassins.length(); idx++) {
            EHandle hAssassin = g_ahAssassins[idx];
            if (!hAssassin.IsValid()) {
                g_ahAssassins.removeAt(idx);
                continue;
            }
            CBaseEntity@ pEntity = hAssassin.GetEntity();
            CBackupFrostNadePlayerData@ pBackupData = g_rglpBackupAssassinPlayerData[pEntity.entindex()];
            if (pBackupData is null) continue;
            pEntity.pev.renderfx = pBackupData.m_iRenderFX;
            pEntity.pev.rendercolor = pBackupData.m_vecRenderColor;
            pEntity.pev.rendermode = pBackupData.m_iRenderMode;
            pEntity.pev.renderamt = pBackupData.m_flRenderAmount;
        }
        for (uint idx = 0; idx < g_ahNemesises.length(); idx++) {
            EHandle hAssassin = g_ahAssassins[idx];
            if (!hAssassin.IsValid()) {
                g_ahAssassins.removeAt(idx);
                continue;
            }
            CBaseEntity@ pEntity = hAssassin.GetEntity();
            CBackupFrostNadePlayerData@ pBackupData = g_rglpBackupAssassinPlayerData[pEntity.entindex()];
            if (pBackupData is null) continue;
            pEntity.pev.renderfx = pBackupData.m_iRenderFX;
            pEntity.pev.rendercolor = pBackupData.m_vecRenderColor;
            pEntity.pev.rendermode = pBackupData.m_iRenderMode;
            pEntity.pev.renderamt = pBackupData.m_flRenderAmount;
        }
        g_rglpBackupAssassinPlayerData.resize(0);
        g_rglpBackupAssassinPlayerData.resize(33);
        return;
    }
    if (!g_bAssassinRound && !g_bNemesisRound && !g_bNightmareMode && !g_bArmageddonMode && !g_bDarkHarvestMode) return;
    if (g_ahAssassins.length() == 0 && g_ahNemesises.length() == 0) return;
    
    for (uint idx = 0; idx < g_ahAssassins.length(); idx++) {
        EHandle hAssassin = g_ahAssassins[idx];
        if (!hAssassin.IsValid()) {
            g_ahAssassins.removeAt(idx);
            continue;
        }
        CBaseEntity@ pEntity = hAssassin.GetEntity();
        pEntity.pev.renderfx = kRenderFxGlowShell;
        pEntity.pev.rendercolor = g_vecYellowColour;
        pEntity.pev.rendermode = kRenderNormal;
        pEntity.pev.renderamt = 16;
        NetworkMessage dlight(MSG_PAS, NetworkMessages::SVC_TEMPENTITY, pEntity.pev.origin);
            dlight.WriteByte(TE_DLIGHT);
            dlight.WriteCoord(pEntity.pev.origin.x);
            dlight.WriteCoord(pEntity.pev.origin.y);
            dlight.WriteCoord(pEntity.pev.origin.z);
            dlight.WriteByte(25); //radius
            dlight.WriteByte(255); //r
            dlight.WriteByte(255); //g
            dlight.WriteByte(0); //b
            dlight.WriteByte(3); //life
            dlight.WriteByte(3); //decay rate
        dlight.End();
    }
    
     for (uint idx = 0; idx < g_ahNemesises.length(); idx++) {
        EHandle hAssassin = g_ahNemesises[idx];
        if (!hAssassin.IsValid()) {
            g_ahNemesises.removeAt(idx);
            continue;
        }
        CBaseEntity@ pEntity = hAssassin.GetEntity();
        pEntity.pev.renderfx = kRenderFxGlowShell;
        pEntity.pev.rendercolor = g_vecRedColour;
        pEntity.pev.rendermode = kRenderNormal;
        pEntity.pev.renderamt = 16;
        NetworkMessage dlight(MSG_PAS, NetworkMessages::SVC_TEMPENTITY, pEntity.pev.origin);
            dlight.WriteByte(TE_DLIGHT);
            dlight.WriteCoord(pEntity.pev.origin.x);
            dlight.WriteCoord(pEntity.pev.origin.y);
            dlight.WriteCoord(pEntity.pev.origin.z);
            dlight.WriteByte(25); //radius
            dlight.WriteByte(255); //r
            dlight.WriteByte(0); //g
            dlight.WriteByte(0); //b
            dlight.WriteByte(3); //life
            dlight.WriteByte(3); //decay rate
        dlight.End();
    }
    
    @g_lpfnMakeAssassinShiny = g_Scheduler.SetTimeout("MakeAssassinShiny", 0.0f);
}

void MakeHumanTanksShiny() {
    if (!g_bMatchStarted) {
        for (uint idx = 0; idx < g_ahHumanTanks.length(); idx++) {
            EHandle hHumanTank = g_ahHumanTanks[idx];
            if (!hHumanTank.IsValid()) {
                g_ahHumanTanks.removeAt(idx);
                continue;
            }
            CBaseEntity@ pEntity = hHumanTank.GetEntity();
            CBackupFrostNadePlayerData@ pBackupData = g_rglpBackupHumanTanksPlayerData[pEntity.entindex()];
            if (pBackupData is null) continue;
            pEntity.pev.renderfx = pBackupData.m_iRenderFX;
            pEntity.pev.rendercolor = pBackupData.m_vecRenderColor;
            pEntity.pev.rendermode = pBackupData.m_iRenderMode;
            pEntity.pev.renderamt = pBackupData.m_flRenderAmount;
        }
        g_rglpBackupHumanTanksPlayerData.resize(0);
        g_rglpBackupHumanTanksPlayerData.resize(33);
        return;
    }
    if (!g_bSniperRound && !g_bSurvivorRound && !g_bNightmareMode && !g_bArmageddonMode && !g_bDarkHarvestMode) return;
    if (g_ahHumanTanks.length() == 0) return;
    
    for (uint idx = 0; idx < g_ahHumanTanks.length(); idx++) {
        EHandle hHumanTank = g_ahHumanTanks[idx];
        if (!hHumanTank.IsValid()) {
            g_ahHumanTanks.removeAt(idx);
            continue;
        }
        CBaseEntity@ pEntity = hHumanTank.GetEntity();
        if (g_abIsSniper[pEntity.entindex()]) {
            pEntity.pev.renderfx = kRenderFxGlowShell;
            pEntity.pev.rendercolor = g_vecGreenColour;
            pEntity.pev.rendermode = kRenderNormal;
            pEntity.pev.renderamt = 16;
            NetworkMessage dlight(MSG_PAS, NetworkMessages::SVC_TEMPENTITY, pEntity.pev.origin);
                dlight.WriteByte(TE_DLIGHT);
                dlight.WriteCoord(pEntity.pev.origin.x);
                dlight.WriteCoord(pEntity.pev.origin.y);
                dlight.WriteCoord(pEntity.pev.origin.z);
                dlight.WriteByte(25); //radius
                dlight.WriteByte(0); //r
                dlight.WriteByte(255); //g
                dlight.WriteByte(0); //b
                dlight.WriteByte(3); //life
                dlight.WriteByte(3); //decay rate
            dlight.End();
        } else if (g_abIsSurvivor[pEntity.entindex()]) {
            pEntity.pev.renderfx = kRenderFxGlowShell;
            pEntity.pev.rendercolor = g_vecBlueColour;
            pEntity.pev.rendermode = kRenderNormal;
            pEntity.pev.renderamt = 16;
            NetworkMessage dlight(MSG_PAS, NetworkMessages::SVC_TEMPENTITY, pEntity.pev.origin);
                dlight.WriteByte(TE_DLIGHT);
                dlight.WriteCoord(pEntity.pev.origin.x);
                dlight.WriteCoord(pEntity.pev.origin.y);
                dlight.WriteCoord(pEntity.pev.origin.z);
                dlight.WriteByte(25); //radius
                dlight.WriteByte(0); //r
                dlight.WriteByte(0); //g
                dlight.WriteByte(255); //b
                dlight.WriteByte(3); //life
                dlight.WriteByte(3); //decay rate
            dlight.End();
        }
    }
    
    @g_lpfnMakeHumanTanksShiny = g_Scheduler.SetTimeout("MakeHumanTanksShiny", 0.0f);
}

void UpdateTimer() {
    if (g_iTimeLeft == 0 || !g_bMatchStarted) {
        HUDNumDisplayParams hideParams;
        hideParams.channel = 15;
        hideParams.flags = HUD_ELEM_HIDDEN;
        g_PlayerFuncs.HudTimeDisplay(null, hideParams);
        MatchEnd();
        
        return;
    }
    HUDNumDisplayParams params;
    params.value = g_iTimeLeft;
    params.x = 0.f;
    params.y = 0.91f;
    params.color1 = RGBA_SVENCOOP;
    params.spritename = "stopwatch";
    params.channel = 15;
    params.flags = HUD_ELEM_SCR_CENTER_X | HUD_ELEM_DEFAULT_ALPHA | HUD_TIME_MINUTES | HUD_TIME_SECONDS | HUD_TIME_COUNT_DOWN;
    
    g_PlayerFuncs.HudTimeDisplay(null, params);
    g_iTimeLeft--;
    @g_lpfnUpdateTimer = g_Scheduler.SetTimeout("UpdateTimer", 1.0f);
}

bool ZM_UTIL_IsPlayerAllowedToOpenAdminMenu(const string& in _SteamID) {
    for (uint idx = 0; idx < g_rglpszAdmins.length(); idx++) {
        string szSteamID = g_rglpszAdmins[idx];
        
        if (szSteamID == _SteamID)
            return true;
    }
    
    return false;
}

void ZM_UTIL_RegenerateMenuItemsFromPlayerList(CCustomTextMenu@ _Menu) {
    array<CBasePlayer@> apPlayers;
    for (int idx = 1; idx <= g_Engine.maxClients; idx++) {
        CBasePlayer@ player = g_PlayerFuncs.FindPlayerByIndex(idx);
        if (player !is null /* && player.IsConnected() */) {
            //_Menu.AddItem((player.pev.netname));
            apPlayers.insertLast(player);
        }
    }
    
    int nCount = 1;
    
    int iMaxEntriesPerPage = apPlayers.length() <= 9 ? 9 : 7;
    
    for (uint idx = 0; idx < apPlayers.length(); idx++) {
        CBasePlayer@ player = apPlayers[idx];
        if (nCount < iMaxEntriesPerPage) {
            if (idx != apPlayers.length() - 1) {
                _Menu.AddItem((player.pev.netname));
            } else {
                _Menu.AddItem((player.pev.netname));
            }
            nCount++;
        } else {
            _Menu.AddItem((player.pev.netname));
            nCount = 1;
        }
    }
}

void ZM_GiveAmmoPacksAdminMenu(CCustomTextMenu@ _Menu, CBasePlayer@ _Player, int _Slot, const CCustomTextMenuItem@ _Item, const CCustomTextMenuListener@ _Listener) {
    if (_Item !is null) {
        CBasePlayer@ pReceiver = g_PlayerFuncs.FindPlayerByName(_Item.m_lpszText);
        if (pReceiver is null) {
            g_PlayerFuncs.ClientPrint(_Player, HUD_PRINTTALK, "[ZP] [SM] Something went wrong...\n");
            return;
        }
        
        CShopMenuPlayerData@ pData = g_rglpShopMenuPlayerDataFastAccessor[pReceiver.entindex()];
        if (pData is null) {
            g_PlayerFuncs.ClientPrint(_Player, HUD_PRINTTALK, "[ZP] [SM] Failed to acquire shop menu data!\n");
            return;
        }
        pData.m_iAmmoPacks += 15;
    }
}

void ZM_AdminMenuCB(CCustomTextMenu@ _Menu, CBasePlayer@ _Player, int _Slot, const CCustomTextMenuItem@ _Item, const CCustomTextMenuListener@ _Listener) {
    if (_Item !is null) {
        if (_Item.m_lpszText == "End round") {
            if (!g_bMatchStarted) {
                g_PlayerFuncs.SayText(_Player, "[ZP] [SM] No round is running currently.\n");
                return;
            }
            MatchEnd();
        } else if (_Item.m_lpszText == "Give ammo packs") {
            if (g_lpGiveAmmoPacksAdminMenu !is null) {
                g_lpGiveAmmoPacksAdminMenu.Unregister();
                @g_lpGiveAmmoPacksAdminMenu = null;
            }
            
            if (g_lpGiveAmmoPacksAdminMenu is null) {
                @g_lpGiveAmmoPacksAdminMenu = CCustomTextMenu(ZM_GiveAmmoPacksAdminMenu);
                g_lpGiveAmmoPacksAdminMenu.SetTitle("Give ammo packs");
                ZM_UTIL_RegenerateMenuItemsFromPlayerList(@g_lpGiveAmmoPacksAdminMenu);
                g_lpGiveAmmoPacksAdminMenu.Register();
            }
            
            g_lpGiveAmmoPacksAdminMenu.Open(0, 0, _Player);
        }
    }
}

void ZM_VoteMenuCB(CCustomTextMenu@ _Menu, CBasePlayer@ _Player, int _Slot, const CCustomTextMenuItem@ _Item, const CCustomTextMenuListener@ _Listener) {
    if (_Item !is null) {
        string szSteamID = g_EngineFuncs.GetPlayerAuthId(_Player.edict());
        if (_Item.m_lpszText == "Take vote") {
            ZM_UTIL_RemovePlayerFromVotersInVoteInProgressMaps(szSteamID);
            return;
        }
        CVoteInProgressMap@ pMap = ZM_UTIL_GetVoteInProgressMapByName(_Item.m_lpszText);
        if (pMap is null) {
            g_PlayerFuncs.SayText(_Player, "[ZP] [RTV] Something went wrong when finding the specified map: " + _Item.m_lpszText + ".\n");
            return;
        }
        ZM_UTIL_RemovePlayerFromVotersInVoteInProgressMaps(szSteamID);
        pMap.m_rglpszVoters.insertLast(szSteamID);
        g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[ZP] [RTV] " + string(_Player.pev.netname) + " voted for " + _Item.m_lpszText + " map!\n");
    }
}

void ZM_ShopMenu_OnceLasermineBoughtCallback(cBuyable@ _ThisPtr, EHandle _Customer, CShopMenuPlayerData@ _PlayerData) {
    if (!_Customer.IsValid()) {
        return;
    }
    
    CBaseEntity@ pEntity = _Customer.GetEntity();
    CBasePlayer@ pPlayer = cast<CBasePlayer@>(pEntity);
    
    if (_PlayerData.m_iLaserMines < 4) {
        _PlayerData.m_iLaserMines++;
    } else {
        g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "[ZP] [Shop] You can't carry more than four lasermines with yourself!\n");
        _PlayerData.m_iAmmoPacks += _ThisPtr.m_iCost;
    }
}

void ZM_ShopMenu_OnceSpecialWeaponBoughtCallback(cBuyable@ _ThisPtr, EHandle _Customer, CShopMenuPlayerData@ _PlayerData) {
    if (!_Customer.IsValid()) {
        return;
    }
    
    CBaseEntity@ pEntity = _Customer.GetEntity();
    CBasePlayer@ pPlayer = cast<CBasePlayer@>(pEntity);
    
    array<EHandle>@ pThisPlayerArms = @g_aapBoughtArms[pPlayer.entindex()];
    
    if (_ThisPtr.m_lpszName == "RPG") {
        pPlayer.GiveNamedItem("weapon_rpg", 0, 5);
        CBasePlayerItem@ pItem;
        CBasePlayerWeapon@ pWeapon;
        bool bDone = false;
        for (uint j = 0; j < 10; j++) {
            @pItem = pPlayer.m_rgpPlayerItems(j);
            if (bDone) break;
            while (pItem !is null) {
                @pWeapon = pItem.GetWeaponPtr();
                                
                if (pWeapon.GetClassname() == "weapon_rpg") {
                    bDone = true;
                    pThisPlayerArms.insertLast(EHandle(pWeapon));
                    break;
                }
                                
                @pItem = cast<CBasePlayerItem@>(pItem.m_hNextItem.GetEntity());
            }
        }
    } else if (_ThisPtr.m_lpszName == "Tau Cannon") {
        pPlayer.GiveNamedItem("weapon_gauss", 0, 40);
        CBasePlayerItem@ pItem;
        CBasePlayerWeapon@ pWeapon;
        bool bDone = false;
        for (uint j = 0; j < 10; j++) {
            @pItem = pPlayer.m_rgpPlayerItems(j);
            if (bDone) break;
            while (pItem !is null) {
                @pWeapon = pItem.GetWeaponPtr();
                                
                if (pWeapon.GetClassname() == "weapon_gauss") {
                    bDone = true;
                    pThisPlayerArms.insertLast(EHandle(pWeapon));
                    break;
                }
                                
                @pItem = cast<CBasePlayerItem@>(pItem.m_hNextItem.GetEntity());
            }
        }
    } else if (_ThisPtr.m_lpszName == "Gluon Gun") {
        pPlayer.GiveNamedItem("weapon_egon", 0, 40);
        CBasePlayerItem@ pItem;
        CBasePlayerWeapon@ pWeapon;
        bool bDone = false;
        for (uint j = 0; j < 10; j++) {
            @pItem = pPlayer.m_rgpPlayerItems(j);
            if (bDone) break;
            while (pItem !is null) {
                @pWeapon = pItem.GetWeaponPtr();
                                
                if (pWeapon.GetClassname() == "weapon_egon") {
                    bDone = true;
                    pThisPlayerArms.insertLast(EHandle(pWeapon));
                    break;
                }
                                
                @pItem = cast<CBasePlayerItem@>(pItem.m_hNextItem.GetEntity());
            }
        }
    } else if (_ThisPtr.m_lpszName == "Frost Grenade") {
        pPlayer.GiveNamedItem("weapon_frostgrenade", 0, 1);
            
        CBasePlayerItem@ pItem;
        CBasePlayerWeapon@ pWeapon;
        for (uint j = 0; j < 10; j++) {
            @pItem = pPlayer.m_rgpPlayerItems(j);
            while (pItem !is null) {
                @pWeapon = pItem.GetWeaponPtr();
                            
                if (pWeapon.GetClassname() == "weapon_frostgrenade") {
                    int iPrimaryIdx = pWeapon.PrimaryAmmoIndex();
                    if (iPrimaryIdx != -1) {
                        pPlayer.m_rgAmmo(iPrimaryIdx, pPlayer.m_rgAmmo(iPrimaryIdx) + 1);
                    }
                }
                            
                @pItem = cast<CBasePlayerItem@>(pItem.m_hNextItem.GetEntity());
            }
        }
    } else if (_ThisPtr.m_lpszName == "Fire Grenade") {
        pPlayer.GiveNamedItem("weapon_firegrenade", 0, 1);
            
        CBasePlayerItem@ pItem;
        CBasePlayerWeapon@ pWeapon;
        for (uint j = 0; j < 10; j++) {
            @pItem = pPlayer.m_rgpPlayerItems(j);
            while (pItem !is null) {
                @pWeapon = pItem.GetWeaponPtr();
                            
                if (pWeapon.GetClassname() == "weapon_firegrenade") {
                    int iPrimaryIdx = pWeapon.PrimaryAmmoIndex();
                    if (iPrimaryIdx != -1) {
                        pPlayer.m_rgAmmo(iPrimaryIdx, pPlayer.m_rgAmmo(iPrimaryIdx) + 1);
                    }
                }
                            
                @pItem = cast<CBasePlayerItem@>(pItem.m_hNextItem.GetEntity());
            }
        }
    } else if (_ThisPtr.m_lpszName == "Flare Grenade") {
        pPlayer.GiveNamedItem("weapon_flaregrenade", 0, 1);
            
        CBasePlayerItem@ pItem;
        CBasePlayerWeapon@ pWeapon;
        for (uint j = 0; j < 10; j++) {
            @pItem = pPlayer.m_rgpPlayerItems(j);
            while (pItem !is null) {
                @pWeapon = pItem.GetWeaponPtr();
                            
                if (pWeapon.GetClassname() == "weapon_flaregrenade") {
                    int iPrimaryIdx = pWeapon.PrimaryAmmoIndex();
                    if (iPrimaryIdx != -1) {
                        pPlayer.m_rgAmmo(iPrimaryIdx, pPlayer.m_rgAmmo(iPrimaryIdx) + 1);
                    }
                }
                            
                @pItem = cast<CBasePlayerItem@>(pItem.m_hNextItem.GetEntity());
            }
        }
    } else if (_ThisPtr.m_lpszName == "Infection grenade") {
        pPlayer.GiveNamedItem("weapon_infectgrenade", 0, 1);
            
        CBasePlayerItem@ pItem;
        CBasePlayerWeapon@ pWeapon;
        for (uint j = 0; j < 10; j++) {
            @pItem = pPlayer.m_rgpPlayerItems(j);
            while (pItem !is null) {
                @pWeapon = pItem.GetWeaponPtr();
                            
                if (pWeapon.GetClassname() == "weapon_infectgrenade") {
                    int iPrimaryIdx = pWeapon.PrimaryAmmoIndex();
                    if (iPrimaryIdx != -1) {
                        pPlayer.m_rgAmmo(iPrimaryIdx, pPlayer.m_rgAmmo(iPrimaryIdx) + 1);
                    }
                }
                            
                @pItem = cast<CBasePlayerItem@>(pItem.m_hNextItem.GetEntity());
            }
        }
    }
}

void ZM_ShopMenu_OnceInfiniteAmmoBoughtCallback(cBuyable@ _ThisPtr, EHandle _Customer, CShopMenuPlayerData@ _PlayerData) {
    if (!_Customer.IsValid()) {
        return;
    }
    
    CBaseEntity@ pEntity = _Customer.GetEntity();
    CBasePlayer@ pPlayer = cast<CBasePlayer@>(pEntity);
    int nPlayerIdx = pPlayer.entindex();
    
    if (g_abHasBoughtInfiniteAmmo[nPlayerIdx]) {
        _PlayerData.m_iAmmoPacks += 50;
        g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "[ZP] [Shop] You already have bought this!\n");
        return;
    }
    
    g_abHasBoughtInfiniteAmmo[nPlayerIdx] = true;
}

void ZM_ShopMenu_OnceAntidotBoughtCallback(cBuyable@ _ThisPtr, EHandle _Customer, CShopMenuPlayerData@ _PlayerData) {
    if (!_Customer.IsValid()) {
        return;
    }
    
    CBaseEntity@ pEntity = _Customer.GetEntity();
    CBasePlayer@ pPlayer = cast<CBasePlayer@>(pEntity);
    
    CPlayerData@ pData = ZM_UTIL_GetPlayerDataBySteamID(_PlayerData.m_lpszSteamID);
    if (pData is null) {
        return;
    }
    if (pPlayer.pev.max_health == (pData.m_lpZombieClass.m_flHealth * 2.f)) {
        _PlayerData.m_iAmmoPacks += 30;
        g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "[ZP] [Shop] First zombie cannot use antidot!\n");
        return;
    }
    
    g_abZombies[pPlayer.entindex()] = false;
    for (uint idx = 0; idx < g_ahZombies.length(); idx++) {
        EHandle hZombie = g_ahZombies[idx];
        if (!hZombie.IsValid()) continue;
        if (hZombie.GetEntity().entindex() == pPlayer.entindex()) {
            g_ahZombies.removeAt(idx);
            break;
        }
    }
    
    pPlayer.RemoveAllItems(false);
    pPlayer.SetClassification(2); //CLASS_PLAYER
    pPlayer.SendScoreInfo();
    pPlayer.pev.max_health = 100;
    pPlayer.pev.gravity = 1.0f;
    pPlayer.pev.maxspeed = 270.f;
    string szSteamID = g_EngineFuncs.GetPlayerAuthId(pEntity.edict());
    pPlayer.GiveNamedItem("weapon_frostgrenade", 0, 1);
    pPlayer.GiveNamedItem("weapon_flaregrenade", 0, 1);
    pPlayer.GiveNamedItem("weapon_firegrenade", 0, 1);
            
    CBasePlayerItem@ pItem;
    CBasePlayerWeapon@ pWeapon;
    for (uint j = 0; j < 10; j++) {
        @pItem = pPlayer.m_rgpPlayerItems(j);
        while (pItem !is null) {
            @pWeapon = pItem.GetWeaponPtr();
                            
            if (pWeapon.GetClassname().Find("grenade") != String::INVALID_INDEX) {
                int iPrimaryIdx = pWeapon.PrimaryAmmoIndex();
                if (iPrimaryIdx != -1) {
                    pPlayer.m_rgAmmo(iPrimaryIdx, 1);
                }
            }
                            
            @pItem = cast<CBasePlayerItem@>(pItem.m_hNextItem.GetEntity());
        }
    }
    if (pData is null) return;
    pPlayer.SetOverriddenPlayerModel(pData.m_lpszBackupModel);
    pData.m_bHasGotFirstWeapon = false;
    pData.m_bHasGotSecondaryWeapon = false;
    g_lpChoosePrimaryWeaponMenu.Open(0, 0, pPlayer);
    
    HUDTextParams params;
    params.r1 = 0;
    params.g1 = 255;
    params.b1 = 255;
    params.a1 = 160;
    params.a2 = 160;
    params.x = 0.1f;
    params.y = -1.0f;
    params.effect = 0;
    params.fadeinTime = 0.5f;
    params.fadeoutTime = 0.5f;
    params.holdTime = 2.0f;
    params.channel = 2;
            
    g_PlayerFuncs.HudMessageAll(params, string(pPlayer.pev.netname) + " was cured by antidot...");
}

void ZM_ShopMenu_OnceArmorVestBoughtCallback(cBuyable@ _ThisPtr, EHandle _Customer, CShopMenuPlayerData@ _PlayerData) {
    if (!_Customer.IsValid()) {
        return;
    }
    
    CBaseEntity@ pEntity = _Customer.GetEntity();
    CBasePlayer@ pPlayer = cast<CBasePlayer@>(pEntity);

    pPlayer.pev.armorvalue += 50;
    if (pPlayer.pev.armorvalue > 100)
        pPlayer.pev.armorvalue = 100;
}

void ZM_ShopMenu_OnceSandbagsBoughtCallback(cBuyable@ _ThisPtr, EHandle _Customer, CShopMenuPlayerData@ _PlayerData) {
    if (!_Customer.IsValid()) {
        return;
    }
    
    CBaseEntity@ pEntity = _Customer.GetEntity();
    CBasePlayer@ pPlayer = cast<CBasePlayer@>(pEntity);

    if (_PlayerData.m_iSandbags < 2) {
        _PlayerData.m_iSandbags++;
    } else {
        g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "[ZP] [Shop] You can't carry more than two sandbags with yourself!\n");
        _PlayerData.m_iAmmoPacks += _ThisPtr.m_iCost;
    }
}

void ZM_ShopMenuCB(CCustomTextMenu@ _Menu, CBasePlayer@ _Player, int _Slot, const CCustomTextMenuItem@ _Item, const CCustomTextMenuListener@ _Listener) {
    if (_Item !is null) {
        if (g_bSniperRound || g_bSurvivorRound || g_bNemesisRound || g_bAssassinRound || g_bNightmareMode || g_bArmageddonMode || g_bDarkHarvestMode) {
            g_PlayerFuncs.ClientPrint(_Player, HUD_PRINTTALK, "[ZP] Extra items are disabled in this round.\n");
            return;
        }
        string szBuyableName = ":D";
        _Item.m_pUserData.retrieve(szBuyableName);
        if (szBuyableName == ":D") {
            g_PlayerFuncs.ClientPrint(_Player, HUD_PRINTTALK, "[ZP] [Shop] Something went really wrong... Sorry for the inconvience.\n");
            return;
        }
        cBuyable@ pBuyable = ZM_UTIL_FindBuyableByName(szBuyableName);
        if (pBuyable is null) {
            g_PlayerFuncs.ClientPrint(_Player, HUD_PRINTTALK, "[ZP] [Shop] Something went really wrong... Sorry for the inconvience.\n");
            return;
        }
        int nPlayerIdx = _Player.entindex();
        CShopMenuPlayerData@ pData = g_rglpShopMenuPlayerDataFastAccessor[nPlayerIdx];
        if (pData is null) {
            g_PlayerFuncs.ClientPrint(_Player, HUD_PRINTTALK, "[ZP] [Shop] We couldn't retrieve some info about you. Please try buying stuff some time later!\n");
            return;
        }
        if (pData.m_iAmmoPacks < pBuyable.m_iCost) {
            g_PlayerFuncs.ClientPrint(_Player, HUD_PRINTTALK, "[ZP] [Shop] You don't have enough ammo packs to afford that thing!\n");
            return;
        }
        if (g_abZombies[nPlayerIdx] && !pBuyable.m_bIsAvailableOnlyForZombies) {
            g_PlayerFuncs.ClientPrint(_Player, HUD_PRINTTALK, "[ZP] [Shop] This thing is available only for humans =(\n");
            return;
        }
        if (!g_abZombies[nPlayerIdx] && pBuyable.m_bIsAvailableOnlyForZombies) {
            g_PlayerFuncs.ClientPrint(_Player, HUD_PRINTTALK, "[ZP] [Shop] This thing is available only for zombies =(\n");
            return;
        }
        pData.m_iAmmoPacks -= pBuyable.m_iCost;
        pBuyable.m_lpfnOnceBoughtCallback(@pBuyable, EHandle(_Player), @pData);
        ZM_UTIL_WriteShopPlayerData();
    }
}

void ZM_ManageBuyablesMenuCB(CCustomTextMenu@ _Menu, CBasePlayer@ _Player, int _Slot, const CCustomTextMenuItem@ _Item, const CCustomTextMenuListener@ _Listener) {
    if (_Item !is null) {
        if (g_bSniperRound || g_bSurvivorRound || g_bNemesisRound || g_bAssassinRound || g_bNightmareMode || g_bArmageddonMode || g_bDarkHarvestMode) {
            g_PlayerFuncs.ClientPrint(_Player, HUD_PRINTTALK, "[ZP] Extra items are disabled in this round.\n");
            return;
        }
        CShopMenuPlayerData@ pData = g_rglpShopMenuPlayerDataFastAccessor[_Player.entindex()];
        if (pData is null) {
            g_PlayerFuncs.ClientPrint(_Player, HUD_PRINTTALK, "[ZP] [Shop] Something went really wrong... Sorry for the inconvience.\n");
            return;
        }
        
        int nPlayerIdx = _Player.entindex();
    
        if (_Item.m_lpszText == "Print stats") {
            g_PlayerFuncs.SayText(_Player, "[ZP] [Shop] You have " + string(pData.m_iSandbags) + " sandbags and " + string(pData.m_iLaserMines) + " lasermines. Use '/zpsetlaser' to place a lasermine and '/zpdellaser' to take it back.\n");
        } else if (_Item.m_lpszText == "Place sandbags") {
            if (g_abZombies[nPlayerIdx]) {
                g_PlayerFuncs.SayText(_Player, "[ZP] [Shop] Why does a zombie need sandbags?\n");
                return;
            }
            if (!_Player.IsAlive()) {
                g_PlayerFuncs.SayText(_Player, "[ZP] [Shop] Why does a dead human need sandbags?\n");
                return;
            }
            Observer@ pObserver = _Player.GetObserver();
            if (pObserver !is null && pObserver.IsObserver()) {
                g_PlayerFuncs.SayText(_Player, "[ZP] [Shop] Why does a dead human need sandbags?\n");
                return;
            }
            if (pData.m_iSandbags < 1) {
                g_PlayerFuncs.SayText(_Player, "[ZP] [Shop] You don't have sandbags!\n");
                return;
            }
            
            g_EngineFuncs.MakeVectors(_Player.pev.v_angle);
            Vector vecStart = _Player.GetGunPosition();
            TraceResult tr;
            g_Utility.TraceLine(vecStart, vecStart + g_Engine.v_forward * 320.f, dont_ignore_monsters, _Player.edict(), tr);
            if (tr.flFraction < 1.0f) {
                Vector vecSandbagsPosition = Vector(tr.vecEndPos.x, tr.vecEndPos.y, tr.vecEndPos.z + 20.f);
                CBaseEntity@ pEntity = g_EntityFuncs.Create("zpc_sandbags", vecSandbagsPosition, g_vecZero, true, null);
                @pEntity.pev.euser3 = _Player.edict();
                CSandbags@ pSandbags = cast<CSandbags@>(CastToScriptClass(pEntity));
                pSandbags.Spawn();
                g_EntityFuncs.DispatchSpawn(pEntity.edict());
                pEntity.SetPlayerAlly(true);
                pEntity.SetPlayerAllyDirect(true);
                if (pData.m_flLastTakenSandbagHealth != 1.f) {
                    pEntity.pev.fuser3 = pData.m_flLastTakenSandbagHealth;
                    pData.m_flLastTakenSandbagHealth = -1.f;
                }
                pData.m_iSandbags--;
                ZM_UTIL_WriteShopPlayerData();
            }
        } else if (_Item.m_lpszText == "Take sandbags") {
            if (g_abZombies[nPlayerIdx]) {
                g_PlayerFuncs.SayText(_Player, "[ZP] [Shop] Why does a zombie need sandbags?\n");
                return;
            }
            if (!_Player.IsAlive()) {
                g_PlayerFuncs.SayText(_Player, "[ZP] [Shop] Why does a dead human need sandbags?\n");
                return;
            }
            Observer@ pObserver = _Player.GetObserver();
            if (pObserver !is null && pObserver.IsObserver()) {
                g_PlayerFuncs.SayText(_Player, "[ZP] [Shop] Why does a dead human need sandbags?\n");
                return;
            }
            
            g_EngineFuncs.MakeVectors(_Player.pev.v_angle);
            Vector vecStart = _Player.GetGunPosition();
            TraceResult tr;
            g_Utility.TraceLine(vecStart, vecStart + g_Engine.v_forward * 320.f, dont_ignore_monsters, _Player.edict(), tr);
            if (tr.pHit !is null) {
                CBaseEntity@ pEntity = g_EntityFuncs.Instance(tr.pHit);
                if (pEntity.GetClassname() != "zpc_sandbags") {
                    g_PlayerFuncs.ClientPrint(_Player, HUD_PRINTTALK, "[ZP] [Shop] No sandbags found after your crosshair!\n");
                    return;
                }
                if (pEntity.pev.euser3 !is null) {
                    CBaseEntity@ pOwner = g_EntityFuncs.Instance(pEntity.pev.euser3);
                    if (pOwner is _Player) {
                        if (pData.m_iSandbags >= 2) {
                            g_PlayerFuncs.SayText(_Player, "[ZP] [Shop] You can't carry more than two sandbags with yourself!\n");
                            return;
                        }
                        pData.m_flLastTakenSandbagHealth = pEntity.pev.health;
                        g_EntityFuncs.Remove(pEntity);
                        pData.m_iSandbags++;
                        ZM_UTIL_WriteShopPlayerData();
                    } else {
                        g_PlayerFuncs.SayText(_Player, "[ZP] [Shop] You're not the owner of these sandbags.\n");
                        return;
                    }
                }
            }
        } else if (_Item.m_lpszText == "Place lasermine") {
            if (!_Player.IsAlive()) {
                g_PlayerFuncs.SayText(_Player, "[ZP] [Shop] Why does a dead human needs a lasermine?\n");
                return;
            }
            Observer@ pObserver = _Player.GetObserver();
            if (pObserver !is null && pObserver.IsObserver()) {
                g_PlayerFuncs.SayText(_Player, "[ZP] [Shop] Why does a dead human needs a lasermine?\n");
                return;
            }
            if (pData.m_iLaserMines < 1) {
                g_PlayerFuncs.SayText(_Player, "[ZP] [Shop] You don't have lasermines!\n");
                return;
            }
            
            g_EngineFuncs.MakeVectors(_Player.pev.v_angle);
            Vector vecStart = _Player.GetGunPosition();
            TraceResult tr;
            g_Utility.TraceLine(vecStart, vecStart + g_Engine.v_forward * 320.f, dont_ignore_monsters, _Player.edict(), tr);
            if (tr.flFraction < 1.0f) {
                Vector vecMinePosition = Vector(tr.vecEndPos.x, tr.vecEndPos.y, tr.vecEndPos.z);
                Vector vecAngles = Math.VecToAngles(tr.vecPlaneNormal);
                float flYaw = vecAngles.y;
                float flForward = ZM_UTIL_Degree2Radians(flYaw);
                vecMinePosition = Vector(vecMinePosition.x + cos(flForward) * 8.f, vecMinePosition.y + sin(flForward) * 8.f, vecMinePosition.z);
                TraceResult allSafeTraceResult;
                g_Utility.TraceLine(vecMinePosition, vecMinePosition, ignore_monsters, dont_ignore_glass, null, allSafeTraceResult);
                Vector vecUpwards = Vector(vecMinePosition.x, vecMinePosition.y, vecMinePosition.z + 8.f);
                Vector vecDownwards = Vector(vecMinePosition.x, vecMinePosition.y, vecMinePosition.z - 8.f);
                if (allSafeTraceResult.flFraction != 1.0f || allSafeTraceResult.fAllSolid == 1) {
                    g_Utility.TraceLine(vecMinePosition, vecUpwards, ignore_monsters, dont_ignore_glass, null, allSafeTraceResult);
                    if (allSafeTraceResult.flFraction != 1.0f || allSafeTraceResult.fAllSolid == 1) {
                        g_Utility.TraceLine(vecMinePosition, vecDownwards, ignore_monsters, dont_ignore_glass, null, allSafeTraceResult);
                        if (allSafeTraceResult.flFraction != 1.0f || allSafeTraceResult.fAllSolid == 1) {
                            g_PlayerFuncs.SayText(_Player, "[ZP] [Shop] You can't place a lasermine there!\n");
                            return;
                        } else {
                            vecMinePosition = vecDownwards;
                        }
                    } else {
                        vecMinePosition = vecUpwards;
                    }
                }
                CBaseEntity@ pEntity = g_EntityFuncs.Create("zpc_lasermine", vecMinePosition, vecAngles, true, null);
                @pEntity.pev.euser3 = _Player.edict();
                CLaserMine@ pLaserMine = cast<CLaserMine@>(CastToScriptClass(pEntity));
                pLaserMine.Spawn();
                bool bAlly = !g_abZombies[nPlayerIdx];
                pLaserMine.m_cMode = bAlly ? 0 : 1;
                g_EntityFuncs.DispatchSpawn(pEntity.edict());
                if (pData.m_flLastTakenLaserMineHealth != 1.f) {
                    pEntity.pev.fuser3 = pData.m_flLastTakenLaserMineHealth;
                    pData.m_flLastTakenLaserMineHealth = -1.f;
                }
                pData.m_iLaserMines--;
                ZM_UTIL_WriteShopPlayerData();
                pEntity.SetPlayerAlly(bAlly);
                pEntity.SetPlayerAllyDirect(bAlly);
            }
        } else if (_Item.m_lpszText == "Take lasermine") {
            if (!_Player.IsAlive()) {
                g_PlayerFuncs.SayText(_Player, "[ZP] [Shop] Why does a dead human need a lasermine?\n");
                return;
            }
            Observer@ pObserver = _Player.GetObserver();
            if (pObserver !is null && pObserver.IsObserver()) {
                g_PlayerFuncs.SayText(_Player, "[ZP] [Shop] Why does a dead human need a lasermine?\n");
                return;
            }
            
            g_EngineFuncs.MakeVectors(_Player.pev.v_angle);
            Vector vecStart = _Player.GetGunPosition();
            TraceResult tr;
            g_Utility.TraceLine(vecStart, vecStart + g_Engine.v_forward * 320.f, dont_ignore_monsters, _Player.edict(), tr);
            if (tr.pHit !is null) {
                CBaseEntity@ pEntity = g_EntityFuncs.Instance(tr.pHit);
                if (pEntity.GetClassname() != "zpc_lasermine") {
                    g_PlayerFuncs.ClientPrint(_Player, HUD_PRINTTALK, "[ZP] [Shop] No lasermines found after your crosshair!\n");
                    return;
                }
                if (pEntity.pev.euser3 !is null) {
                    CBaseEntity@ pOwner = g_EntityFuncs.Instance(pEntity.pev.euser3);
                    if (pOwner is _Player) {
                        if (pData.m_iLaserMines >= 4) {
                            g_PlayerFuncs.SayText(_Player, "[ZP] [Shop] You can't carry more than four lasermines with yourself!\n");
                            return;
                        }
                        pData.m_flLastTakenLaserMineHealth = pEntity.pev.health;
                        g_EntityFuncs.Remove(pEntity);
                        pData.m_iLaserMines++;
                        ZM_UTIL_WriteShopPlayerData();
                    } else {
                        g_PlayerFuncs.SayText(_Player, "[ZP] [Shop] You're not the owner of this lasermine.\n");
                        return;
                    }
                }
            }
        }
    }
}

void ZM_MainMenuCB(CCustomTextMenu@ _Menu, CBasePlayer@ _Player, int _Slot, const CCustomTextMenuItem@ _Item, const CCustomTextMenuListener@ _Listener) {
    if (_Item !is null) {
        if (_Item.m_lpszText == "Buy weapons") {
            if (!g_bMatchStarted && !g_bMatchStarting) return;
            string szSteamID = g_EngineFuncs.GetPlayerAuthId(_Player.edict());
            if (ZM_UTIL_IsPlayerZombie(szSteamID)) return;
            CPlayerData@ pData = ZM_UTIL_GetPlayerDataBySteamID(szSteamID);
            if (pData is null) {
                @pData = CPlayerData(szSteamID);
                g_rglpPlayerDatas.insertLast(pData);
            }
            if (!pData.m_bHasGotFirstWeapon) {
                g_lpChoosePrimaryWeaponMenu.Open(0, 0, _Player);
            } else if (pData.m_bHasGotFirstWeapon && !pData.m_bHasGotSecondaryWeapon) {
                g_lpChooseSecondaryWeaponMenu.Open(0, 0, _Player);
            }
        } else if (_Item.m_lpszText == "Choose Zombie Class") {
            if (g_bMatchStarted) {
                g_PlayerFuncs.SayText(_Player, "[ZP] Wait until round finishes!\n");
                return;
            }
            string szSteamID = g_EngineFuncs.GetPlayerAuthId(_Player.edict());
            CPlayerData@ pData = ZM_UTIL_GetPlayerDataBySteamID(szSteamID);
            if (pData is null) {
                @pData = CPlayerData(szSteamID);
                g_rglpPlayerDatas.insertLast(pData);
            }
            if (g_lpChooseZombieClassMenu is null) {
                @g_lpChooseZombieClassMenu = CCustomTextMenu(ZM_ChooseZombieClassMenuCB, false);
                g_lpChooseZombieClassMenu.MakeExitButtonTheSameColourAsTitle();
                g_lpChooseZombieClassMenu.SetItemDelimeter(':');
                g_lpChooseZombieClassMenu.SetTitle("Zombie Class");
                for (uint idx = 0; idx < g_rglpZombieClasses.length(); idx++) {
                    CZombieClass@ lpKlass = g_rglpZombieClasses[idx];
                    if (!lpKlass.m_bCanBeSelectedViaMenu) continue;
                    g_lpChooseZombieClassMenu.AddItem(lpKlass.m_lpszName + " Zombie \\y" + lpKlass.m_lpszDescription, any(lpKlass.m_lpszName));
                }
                g_lpChooseZombieClassMenu.Register();
            }
            g_lpChooseZombieClassMenu.Open(0, 0, _Player);
        } else if (_Item.m_lpszText == "Admin Menu") {
            string szSteamID = g_EngineFuncs.GetPlayerAuthId(_Player.edict());
            if (!ZM_UTIL_IsPlayerAllowedToOpenAdminMenu(szSteamID)) {
                g_PlayerFuncs.SayText(_Player, "[ZP] You do not have access.\n");
                return;
            }
            if (g_lpAdminMenu is null) {
                @g_lpAdminMenu = CCustomTextMenu(ZM_AdminMenuCB, false);
                g_lpAdminMenu.MakeExitButtonTheSameColourAsTitle();
                g_lpAdminMenu.SetItemDelimeter(':');
                g_lpAdminMenu.SetTitle("Constantium's ZombieMod Admin Panel");
                g_lpAdminMenu.AddItem("End round");
                g_lpAdminMenu.AddItem("Give ammo packs");
                g_lpAdminMenu.Register();
            }
            g_lpAdminMenu.Open(0, 0, _Player);
        } else if (_Item.m_lpszText == "Buy Extra Items") {
            if (g_bSniperRound || g_bSurvivorRound || g_bNemesisRound || g_bAssassinRound || g_bNightmareMode || g_bArmageddonMode || g_bDarkHarvestMode) {
                g_PlayerFuncs.ClientPrint(_Player, HUD_PRINTTALK, "[ZP] Extra items are disabled in this round.\n");
                return;
            }
            if (!_Player.IsAlive()) {
                return;
            }
        
            if (g_lpShopMenu is null) {
                @g_lpShopMenu = CCustomTextMenu(ZM_ShopMenuCB, false);
                g_lpShopMenu.MakeExitButtonTheSameColourAsTitle();
                g_lpShopMenu.SetItemDelimeter(':');
                g_lpShopMenu.SetTitle("Shop");
                for (uint idx = 0; idx < g_alpBuyables.length(); idx++) {
                    cBuyable@ pBuyable = g_alpBuyables[idx];
                    if (!pBuyable.m_bIsAvailableOnlyForZombies)
                        g_lpShopMenu.AddItem(pBuyable.m_lpszName + " \\y~ " + string(pBuyable.m_iCost) + " AP", any(pBuyable.m_lpszName));
                }
                g_lpShopMenu.Register();
            }
            if (g_lpZombiesShopMenu is null) {
                @g_lpZombiesShopMenu = CCustomTextMenu(ZM_ShopMenuCB, false);
                g_lpZombiesShopMenu.MakeExitButtonTheSameColourAsTitle();
                g_lpZombiesShopMenu.SetItemDelimeter(':');
                g_lpZombiesShopMenu.SetTitle("Shop");
                for (uint idx = 0; idx < g_alpBuyables.length(); idx++) {
                    cBuyable@ pBuyable = g_alpBuyables[idx];
                    if (pBuyable.m_bIsAvailableOnlyForZombies)
                        g_lpZombiesShopMenu.AddItem(pBuyable.m_lpszName + " \\y~ " + string(pBuyable.m_iCost) + " AP", any(pBuyable.m_lpszName));
                }
                g_lpZombiesShopMenu.Register();
            }
            if (g_abZombies[_Player.entindex()])
                g_lpZombiesShopMenu.Open(0, 0, _Player);
            else
                g_lpShopMenu.Open(0, 0, _Player);
        } else if (_Item.m_lpszText == "a") { //debug
            _Player.GiveNamedItem("weapon_frostgrenade", 0, 1);
            _Player.GiveNamedItem("weapon_flaregrenade", 0, 1);
            _Player.GiveNamedItem("weapon_firegrenade", 0, 1);
            
            CBasePlayerItem@ pItem;
            CBasePlayerWeapon@ pWeapon;
            for (uint j = 0; j < 10; j++) {
                @pItem = _Player.m_rgpPlayerItems(j);
                while (pItem !is null) {
                    @pWeapon = pItem.GetWeaponPtr();
                            
                    if (pWeapon.GetClassname().Find("grenade") != String::INVALID_INDEX) {
                        int iPrimaryIdx = pWeapon.PrimaryAmmoIndex();
                        if (iPrimaryIdx != -1) {
                            _Player.m_rgAmmo(iPrimaryIdx, 1);
                        }
                    }
                            
                    @pItem = cast<CBasePlayerItem@>(pItem.m_hNextItem.GetEntity());
                }
            }
        } else if (_Item.m_lpszText == "Manage buyables") {
            if (g_bSniperRound || g_bSurvivorRound || g_bNemesisRound || g_bAssassinRound || g_bNightmareMode || g_bArmageddonMode || g_bDarkHarvestMode) {
                g_PlayerFuncs.ClientPrint(_Player, HUD_PRINTTALK, "[ZP] Extra items are disabled in this round.\n");
                return;
            }
            if (!_Player.IsAlive()) {
                return;
            }
            if (g_lpManageBuyablesMenu is null) {
                @g_lpManageBuyablesMenu = CCustomTextMenu(ZM_ManageBuyablesMenuCB, false);
                g_lpManageBuyablesMenu.MakeExitButtonTheSameColourAsTitle();
                g_lpManageBuyablesMenu.SetItemDelimeter(':');
                g_lpManageBuyablesMenu.SetTitle("Manage buyables");
                g_lpManageBuyablesMenu.AddItem("Print stats");
                g_lpManageBuyablesMenu.AddItem("Place sandbags");
                g_lpManageBuyablesMenu.AddItem("Take sandbags");
                g_lpManageBuyablesMenu.AddItem("Place lasermine");
                g_lpManageBuyablesMenu.AddItem("Take lasermine");
                g_lpManageBuyablesMenu.Register();
            }
            g_lpManageBuyablesMenu.Open(0, 0, _Player);
        } else if (_Item.m_lpszText == "Choose Human Class") {
            if (g_bMatchStarted) {
                g_PlayerFuncs.SayText(_Player, "[ZP] Wait until round finishes!\n");
                return;
            }
            string szSteamID = g_EngineFuncs.GetPlayerAuthId(_Player.edict());
            CPlayerData@ pData = ZM_UTIL_GetPlayerDataBySteamID(szSteamID);
            if (pData is null) {
                @pData = CPlayerData(szSteamID);
                g_rglpPlayerDatas.insertLast(pData);
            }
            if (g_lpChooseHumanClassMenu is null) {
                @g_lpChooseHumanClassMenu = CCustomTextMenu(ZM_ChooseHumanClassMenuCB, false);
                g_lpChooseHumanClassMenu.MakeExitButtonTheSameColourAsTitle();
                g_lpChooseHumanClassMenu.SetItemDelimeter(':');
                g_lpChooseHumanClassMenu.SetTitle("Human Class");
                for (uint idx = 0; idx < g_rglpHumanClasses.length(); idx++) {
                    CHumanClass@ lpKlass = g_rglpHumanClasses[idx];
                    g_lpChooseHumanClassMenu.AddItem(lpKlass.m_lpszName + " \\y" + lpKlass.m_lpszDescription, any(lpKlass.m_lpszName));
                }
                g_lpChooseHumanClassMenu.Register();
            }
            g_lpChooseHumanClassMenu.Open(0, 0, _Player);
        } 
    }
}

void ZM_ChooseHumanClassMenuCB(CCustomTextMenu@ _Menu, CBasePlayer@ _Player, int _Slot, const CCustomTextMenuItem@ _Item, const CCustomTextMenuListener@ _Listener) {
    if (_Item !is null) {
        if (g_bMatchStarted) return;
        string szSteamID = g_EngineFuncs.GetPlayerAuthId(_Player.edict());
        CPlayerData@ pData = ZM_UTIL_GetPlayerDataBySteamID(szSteamID);
        if (pData is null) {
            @pData = CPlayerData(szSteamID);
            g_rglpPlayerDatas.insertLast(pData);
        }
        string szKlassName = ":D";
        _Item.m_pUserData.retrieve(szKlassName);
        CHumanClass@ lpKlass = ZM_UTIL_FindHumanClassByName(szKlassName);
        if (lpKlass is null) {
            g_PlayerFuncs.SayText(_Player, "[ZP] No such human class found: " + szKlassName + "\n");
            return;
        }
        @pData.m_lpHumanClass = lpKlass;
        g_abCarriesNightvision[_Player.entindex()] = false;
        g_PlayerFuncs.ScreenFade(_Player, g_vecGreenColour, 0.0, 0.0, 0, FFADE_IN);
        g_PlayerFuncs.SayText(_Player, "[ZP] Your human class in the next round will be: " + szKlassName + "\n");
        g_PlayerFuncs.SayText(_Player, "[ZP] Health: " + string(int(lpKlass.m_flHealth)) + " | Armour: " + string(int(lpKlass.m_flArmour)) + "\n");
        ZM_UTIL_WriteShopPlayerData();
    }
}

void ZM_ChooseZombieClassMenuCB(CCustomTextMenu@ _Menu, CBasePlayer@ _Player, int _Slot, const CCustomTextMenuItem@ _Item, const CCustomTextMenuListener@ _Listener) {
    if (_Item !is null) {
        if (g_bMatchStarted) return;
        string szSteamID = g_EngineFuncs.GetPlayerAuthId(_Player.edict());
        CPlayerData@ pData = ZM_UTIL_GetPlayerDataBySteamID(szSteamID);
        if (pData is null) {
            @pData = CPlayerData(szSteamID);
            g_rglpPlayerDatas.insertLast(pData);
        }
        string szKlassName = ":D";
        _Item.m_pUserData.retrieve(szKlassName);
        CZombieClass@ lpKlass = ZM_UTIL_FindZombieClassByName(szKlassName);
        if (lpKlass is null) {
            g_PlayerFuncs.SayText(_Player, "[ZP] No such zombie class found: " + szKlassName + "\n");
            return;
        }
        @pData.m_lpZombieClass = lpKlass;
        g_PlayerFuncs.SayText(_Player, "[ZP] Your zombie class after the next infection will be: " + szKlassName + " Zombie\n");
        g_PlayerFuncs.SayText(_Player, "[ZP] Health: " + string(int(lpKlass.m_flHealth)) + " | Speed: " + string(int(lpKlass.m_flMaxSpeed)) + " | Gravity: " + string(int(lpKlass.m_flGravity)) + " | Knockback: " + string(int(lpKlass.m_flKnockback)) + "\n");
        ZM_UTIL_WriteShopPlayerData();
    }
}

void ZM_ChoosePrimaryWeaponMenuCB(CCustomTextMenu@ _Menu, CBasePlayer@ _Player, int _Slot, const CCustomTextMenuItem@ _Item, const CCustomTextMenuListener@ _Listener) {
    if (_Item !is null) {
        string szSteamID = g_EngineFuncs.GetPlayerAuthId(_Player.edict());
        if (ZM_UTIL_IsPlayerZombie(szSteamID)) return;
        if (!g_bMatchStarted && !g_bMatchStarting) return;
        CPlayerData@ pData = ZM_UTIL_GetPlayerDataBySteamID(szSteamID);
        if (pData is null) {
            @pData = CPlayerData(szSteamID);
            g_rglpPlayerDatas.insertLast(pData);
        }
        
        if (_Item.m_lpszText == "M16 Carbine") {
            CBaseEntity@ lpWeapon = g_EntityFuncs.Create("weapon_m16", g_vecZero, g_vecZero, true, null);
            lpWeapon.pev.spawnflags |= (SF_NORESPAWN | SF_CREATEDWEAPON);
            g_EntityFuncs.DispatchSpawn(lpWeapon.edict());
            lpWeapon.Touch(_Player);
        } else {
            _Player.GiveNamedItem(string(g_dictPrimaryWeapons[_Item.m_lpszText]), 0, 0);
        }
        pData.m_bHasGotFirstWeapon = true;
        
        g_lpChooseSecondaryWeaponMenu.Open(0, 0, _Player);
    }
}

void ZM_ChooseSecondaryWeaponMenuCB(CCustomTextMenu@ _Menu, CBasePlayer@ _Player, int _Slot, const CCustomTextMenuItem@ _Item, const CCustomTextMenuListener@ _Listener) {
    if (_Item !is null) {
        string szSteamID = g_EngineFuncs.GetPlayerAuthId(_Player.edict());
        if (ZM_UTIL_IsPlayerZombie(szSteamID)) return;
        if (!g_bMatchStarted && !g_bMatchStarting) return;
        CPlayerData@ pData = ZM_UTIL_GetPlayerDataBySteamID(szSteamID);
        if (pData is null) {
            @pData = CPlayerData(szSteamID);
            g_rglpPlayerDatas.insertLast(pData);
        }
        
        _Player.GiveNamedItem(string(g_dictSecondaryWeapons[_Item.m_lpszText]), 0, 0);
        
        pData.m_bHasGotSecondaryWeapon = true;
    }
}

void UpdateWalkingPlayerAmmoPackHud() {
    if (!g_bIsZM) return;

    for (int idx = 1; idx <= g_Engine.maxClients; idx++) {
        CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(idx);
        if (pPlayer !is null && pPlayer.IsConnected()) {
            Observer@ pObserver = pPlayer.GetObserver();
            if (!pObserver.IsObserver()) {
                int nPlayerIdx = pPlayer.entindex();
                HUDTextParams params;
                if (!g_abZombies[nPlayerIdx]) {
                    params.r1 = 0;
                    params.g1 = 255;
                    params.b1 = 255;
                } else {
                    params.r1 = 255;
                    params.g1 = 255;
                    params.b1 = 0;
                }
                params.x = -1.0f;
                params.y = 1.0f;
                params.effect = 0;
                params.fxTime = 0.0f;
                params.fadeinTime = 0.0f;
                params.fadeoutTime = 0.0f;
                params.holdTime = 4.0f;
                params.channel = 5;
                
                CShopMenuPlayerData@ pData = g_rglpShopMenuPlayerDataFastAccessor[nPlayerIdx];
                if (pData is null) {
                    string szSteamID = g_EngineFuncs.GetPlayerAuthId(pPlayer.edict());
                    @pData = ZM_UTIL_FindShopMenuPlayerDataBySteamID(szSteamID);
                    if (pData is null) {
                        @pData = CShopMenuPlayerData(szSteamID);
                        g_rglpShopMenuPlayerData.insertLast(@pData);
                    }
                    @g_rglpShopMenuPlayerDataFastAccessor[nPlayerIdx] = @pData;
                }
                
                string szMessage = "[HP: " + string(int(pPlayer.pev.health)) + "][Armor: " + string(int(pPlayer.pev.armorvalue)) + "][AP: " + string(pData.m_iAmmoPacks) + "]";
                
                g_PlayerFuncs.HudMessage(pPlayer, params, szMessage);
            } else {
                CBaseEntity@ pObserverTarget = pObserver.GetObserverTarget();
                if (pObserverTarget !is null && pObserverTarget.IsPlayer()) {
                    CBasePlayer@ pTarget = cast<CBasePlayer@>(pObserverTarget);
                    int nTargetIdx = pTarget.entindex();
                    HUDTextParams params;
                    params.r1 = 255;
                    params.g1 = 255;
                    params.b1 = 255;
                    params.x = -1.0f;
                    params.y = 0.8f;
                    params.effect = 0;
                    params.fxTime = 0.0f;
                    params.fadeinTime = 0.0f;
                    params.fadeoutTime = 0.0f;
                    params.holdTime = 4.0f;
                    params.channel = 5;
                    
                    CShopMenuPlayerData@ pData = g_rglpShopMenuPlayerDataFastAccessor[nTargetIdx];
                    if (pData is null) {
                        string szSteamID = g_EngineFuncs.GetPlayerAuthId(pTarget.edict());
                        @pData = ZM_UTIL_FindShopMenuPlayerDataBySteamID(szSteamID);
                        if (pData is null) {
                            @pData = CShopMenuPlayerData(szSteamID);
                            g_rglpShopMenuPlayerData.insertLast(@pData);
                        }
                        @g_rglpShopMenuPlayerDataFastAccessor[nTargetIdx] = @pData;
                    }
                    
                    string szMessage = "[Spectating: " + string(pTarget.pev.netname) + "][HP: " + string(int(pTarget.pev.health)) + "][Armor: " + string(int(pTarget.pev.armorvalue)) + "][AP: " + string(pData.m_iAmmoPacks) + "]";
                    
                    g_PlayerFuncs.HudMessage(pPlayer, params, szMessage);
                }
            }
        }
    }
    
    g_flLastUpdateWalkingPlayerAmmoPackHudTime = g_Engine.time;
    
    @g_lpfnUpdateWalkingPlayerAmmoPackHud = g_Scheduler.SetTimeout("UpdateWalkingPlayerAmmoPackHud", 0.8f);
}

void CalculateVoteResults() {
    if (!g_bIsThereAVoteGoingOn) return;

    CVoteInProgressMap@ pHighest = g_rglpVoteInProgressMaps[0];
    for (uint idx = 1; idx < g_rglpVoteInProgressMaps.length(); idx++) {
        CVoteInProgressMap@ pCurrent = g_rglpVoteInProgressMaps[idx];
        if (pHighest.m_rglpszVoters.length() < pCurrent.m_rglpszVoters.length())
            @pHighest = @pCurrent;
    }
    if (pHighest is g_rglpVoteInProgressMaps[0] && pHighest.m_rglpszVoters.length() == 0) { //Nobody voted?
        @pHighest = g_rglpVoteInProgressMaps[Math.RandomLong(0, g_rglpVoteInProgressMaps.length() - 1)];
        g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[ZP] [RTV] Well, you guys couldn't decide which map you will play, so " + pHighest.m_lpszName + " wins the vote! It had " + string(pHighest.m_rglpszVoters.length()) + " voters.\n");
    } else {
        g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[ZP] [RTV] " + pHighest.m_lpszName + " wins the vote! It had " + string(pHighest.m_rglpszVoters.length()) + " voters.\n");
    }
    
    g_EngineFuncs.ServerCommand("mp_nextmap_cycle " + pHighest.m_lpszName + "\n");
    g_EngineFuncs.ServerExecute();
    CBaseEntity@ pGameEnd = g_EntityFuncs.CreateEntity("game_end");
    pGameEnd.Use(null, null, USE_TOGGLE);
    ZM_UTIL_SendSpeakSoundStuffTextMsg("vox/loading environment on to your computer");
}

void WalkingMadScientistNightVisionGogglesThink() {
    for (int idx = 1; idx <= g_Engine.maxClients; idx++) {
        CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(idx);
        if (pPlayer !is null && pPlayer.IsConnected() && pPlayer.IsAlive()) {
            if (!g_abCarriesNightvision[pPlayer.entindex()]) continue;
            Vector vecSrc = pPlayer.EyePosition();

            NetworkMessage nv(MSG_ONE, NetworkMessages::SVC_TEMPENTITY, pPlayer.edict());
                nv.WriteByte(TE_DLIGHT);
                nv.WriteCoord(vecSrc.x);
                nv.WriteCoord(vecSrc.y);
                nv.WriteCoord(vecSrc.z);
                nv.WriteByte(40);
                nv.WriteByte(int(g_vecGreenColour.x));
                nv.WriteByte(int(g_vecGreenColour.y));
                nv.WriteByte(int(g_vecGreenColour.z));
                nv.WriteByte(2);
                nv.WriteByte(1);
            nv.End();
        }
    }
    
    @g_lpfnWalkingMadScientistNightVisionGogglesThink = g_Scheduler.SetTimeout("WalkingMadScientistNightVisionGogglesThink", 0.1f);
}

HookReturnCode HOOKED_ClientPutInServer(CBasePlayer@ _Player) {
    //g_ahZombies.insertLast(EHandle(_Player));
    //if (!g_bMatchStarted || !g_bMatchStarting) TryStartingAMatch();
    string szSteamID = g_EngineFuncs.GetPlayerAuthId(_Player.edict());
    CShopMenuPlayerData@ pData = ZM_UTIL_FindShopMenuPlayerDataBySteamID(szSteamID);
    if (pData is null) {
        @pData = CShopMenuPlayerData(szSteamID);
        g_rglpShopMenuPlayerData.insertLast(@pData);
    }
    @g_rglpShopMenuPlayerDataFastAccessor[_Player.entindex()] = @pData;
    CPlayerData@ pPlayerData = ZM_UTIL_GetPlayerDataBySteamID(szSteamID);
    if (pPlayerData is null) {
        @pPlayerData = CPlayerData(szSteamID);
        g_rglpPlayerDatas.insertLast(@pPlayerData);
    }
    if (pData.m_lpszHumanClass != "Classic") {
        @pPlayerData.m_lpHumanClass = ZM_UTIL_FindHumanClassByName(pData.m_lpszHumanClass);
        if (pPlayerData.m_lpHumanClass is null) {
            @pPlayerData.m_lpHumanClass = ZM_UTIL_FindHumanClassByName("Classic");
        }
    }
    if (pData.m_lpszZombieClass != "Classic") {
        @pPlayerData.m_lpZombieClass = ZM_UTIL_FindZombieClassByName(pData.m_lpszZombieClass);
        if (pPlayerData.m_lpZombieClass is null) {
            @pPlayerData.m_lpZombieClass = ZM_UTIL_FindZombieClassByName("Classic");
        }
    }

    return HOOK_CONTINUE;
}

HookReturnCode HOOKED_MapChange() {
    if (g_bMatchStarted)
        MatchEnd();
    g_bMatchStarted = false;
    g_bMatchStarting = false;
    g_bIsThereAVoteGoingOn = false;
    g_abHasRockTheVoted.resize(0);
    g_abHasRockTheVoted.resize(33);
    g_rglpVoteInProgressMaps.resize(0);
    g_ahAssassins.resize(0);
    g_ahNemesises.resize(0);
    g_ahHumanTanks.resize(0);
    //please kill me
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_deko2"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_fdust_2x2"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_dust_2x2"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_ice_attack"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_ice_attack2"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_ice_attack3"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_italy"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_nuke"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_snowbase"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_snowbase2"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_texas_night"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_vendetta"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_winter_big"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("choose_campaign_dynamic"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_castlevania_t4"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_darkness_street_c2"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_forsaken_sanctum_p6"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_gorod_new"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_city_new"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_snowrooms2"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_tower4"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_dust_banzuke"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_ice_world_2"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_toxic_house3"));
    g_rglpVoteInProgressMaps.insertLast(CVoteInProgressMap("zm_prison"));
    for (uint idx = 0; idx < g_rglpPlayerDatas.length(); idx++) {
        CPlayerData@ pData = g_rglpPlayerDatas[idx];
        pData.m_bHasGotFirstWeapon = false;
        pData.m_bHasGotSecondaryWeapon = false;
        if (pData.m_lpBackupZombieClass is null)
            continue;
        @pData.m_lpZombieClass = @pData.m_lpBackupZombieClass;
        @pData.m_lpBackupZombieClass = null;
    }
    if (g_lpfnPreMatchStart !is null && !g_lpfnPreMatchStart.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(@g_lpfnPreMatchStart);
        @g_lpfnPreMatchStart = null;
    }
    if (g_lpfnPostMatchStart !is null && !g_lpfnPostMatchStart.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(@g_lpfnPostMatchStart);
        @g_lpfnPostMatchStart = null;
    }
    if (g_lpfnMatchStartCountdown !is null && !g_lpfnMatchStartCountdown.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(@g_lpfnMatchStartCountdown);
        @g_lpfnMatchStartCountdown = null;
    }
    if (g_lpfnUpdateTimer !is null && !g_lpfnUpdateTimer.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(@g_lpfnUpdateTimer);
        @g_lpfnUpdateTimer = null;
    }
    if (g_lpfnForceZombieModels !is null && !g_lpfnForceZombieModels.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(@g_lpfnForceZombieModels);
        @g_lpfnForceZombieModels = null;
    }
    if (g_lpfnSafety !is null && !g_lpfnSafety.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(@g_lpfnSafety);
        @g_lpfnSafety = null;
    }
    if (g_lpfnRespawnPlayers !is null && !g_lpfnRespawnPlayers.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(@g_lpfnRespawnPlayers);
        @g_lpfnRespawnPlayers = null;
    }
    if (g_lpfnResetPlayerStates !is null && !g_lpfnResetPlayerStates.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(@g_lpfnResetPlayerStates);
        @g_lpfnResetPlayerStates = null;
    }
    if (g_lpfnTryStartingAMatch !is null && !g_lpfnTryStartingAMatch.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(g_lpfnTryStartingAMatch);
        @g_lpfnTryStartingAMatch = null;
    }
    if (g_lpfnNotifier !is null && !g_lpfnNotifier.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(g_lpfnNotifier);
        @g_lpfnNotifier = null;
    }
    if (g_lpfnOpenWeaponSelectMenu !is null && !g_lpfnOpenWeaponSelectMenu.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(g_lpfnOpenWeaponSelectMenu);
        @g_lpfnOpenWeaponSelectMenu = null;
    }
    if (g_lpfnMakeHumanTanksShiny !is null && !g_lpfnMakeHumanTanksShiny.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(g_lpfnMakeHumanTanksShiny);
        @g_lpfnMakeHumanTanksShiny = null;
    }
    if (g_lpfnMakeAssassinShiny !is null && !g_lpfnMakeAssassinShiny.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(g_lpfnMakeAssassinShiny);
        @g_lpfnMakeAssassinShiny = null;
    }
    if (g_lpfnCalculateVoteResults !is null && !g_lpfnCalculateVoteResults.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(g_lpfnCalculateVoteResults);
        @g_lpfnCalculateVoteResults = null;
    }
    if (g_lpfnUpdateWalkingPlayerAmmoPackHud !is null && !g_lpfnUpdateWalkingPlayerAmmoPackHud.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(g_lpfnUpdateWalkingPlayerAmmoPackHud);
        @g_lpfnUpdateWalkingPlayerAmmoPackHud = null;
    }
    if (g_lpfnRemovePipeWrenchesFromNonEngineers !is null && !g_lpfnRemovePipeWrenchesFromNonEngineers.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(@g_lpfnRemovePipeWrenchesFromNonEngineers);
        @g_lpfnRemovePipeWrenchesFromNonEngineers = null;
    }
    if (g_lpfnWalkingMadScientistNightVisionGogglesThink !is null && !g_lpfnWalkingMadScientistNightVisionGogglesThink.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(@g_lpfnWalkingMadScientistNightVisionGogglesThink);
        @g_lpfnWalkingMadScientistNightVisionGogglesThink = null;
    }
    if (g_lpfnMatchCleanup !is null && !g_lpfnMatchCleanup.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(@g_lpfnMatchCleanup);
        @g_lpfnMatchCleanup = null;
    }

    return HOOK_CONTINUE;
}

HookReturnCode HOOKED_MessageBegin(int _MsgDestination, int _MsgType, Vector _Origin, edict_t@ _Edict, uint& out _CancelOriginalCall) {
    CustomMenus_HandleMessageBegin(_MsgDestination, _MsgType, _Origin, @_Edict);

    return HOOK_CONTINUE;
}

HookReturnCode HOOKED_ClientCommand(edict_t@ _Edict, uint& out _CancelOriginalCall) {
    string szFirstArg = g_EngineFuncs.Cmd_Argv(0);
    szFirstArg = szFirstArg.ToLowercase();
    
    if (szFirstArg == "menuselect") {
        int iSlot = atoi(g_EngineFuncs.Cmd_Argv(1)) - 1;
        if (iSlot < 0) {
            return HOOK_CONTINUE;
        }
    
        if (CustomMenus_HandleMenuselectConCmd(_Edict, iSlot)) return HOOK_CONTINUE;
        
        return HOOK_CONTINUE;
    }

    return HOOK_CONTINUE;
}

HookReturnCode HOOKED_ClientSay(SayParameters@ _Params) {
    if (!g_bIsZM) return HOOK_CONTINUE;

    const CCommand@ args = _Params.GetArguments();
    if (args.ArgC() > 0 and (args[0].Find("/zpmenu") == 0)) {
        _Params.ShouldHide = true;
        if (g_lpMainMenu is null) {
            @g_lpMainMenu = CCustomTextMenu(ZM_MainMenuCB, false);
            g_lpMainMenu.MakeExitButtonTheSameColourAsTitle();
            g_lpMainMenu.SetItemDelimeter(':');
            g_lpMainMenu.SetTitle("Constantium's ZombieMod");
            g_lpMainMenu.AddItem("Buy weapons");
            g_lpMainMenu.AddItem("Buy Extra Items");
            g_lpMainMenu.AddItem("Choose Zombie Class");
            g_lpMainMenu.AddItem("Choose Human Class");
            g_lpMainMenu.AddItem("Manage buyables");
            g_lpMainMenu.AddItem("Admin Menu");
            //g_lpMainMenu.AddItem("a");
            g_lpMainMenu.Register();
        }
        
        g_lpMainMenu.Open(0, 0, _Params.GetPlayer());
        
        return HOOK_HANDLED;
    }
    if (args.ArgC() > 0 && (args[0].Find("/zpsetlaser") == 0)) {
        _Params.ShouldHide = true;
        CBasePlayer@ pPlayer = _Params.GetPlayer();
        CShopMenuPlayerData@ pData = g_rglpShopMenuPlayerDataFastAccessor[pPlayer.entindex()];
        if (pData is null) {
            g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "[ZP] [Wrapper] Something went really wrong when we were looking up for your data...\n");
            return HOOK_CONTINUE;
        }
    
        if (!pPlayer.IsAlive()) {
            g_PlayerFuncs.SayText(pPlayer, "[ZP] [Shop] Why does a dead human needs a lasermine?\n");
            return HOOK_CONTINUE;
        }
        Observer@ pObserver = pPlayer.GetObserver();
        if (pObserver !is null && pObserver.IsObserver()) {
            g_PlayerFuncs.SayText(pPlayer, "[ZP] [Shop] Why does a dead human needs a lasermine?\n");
            return HOOK_CONTINUE;
        }
        if (pData.m_iLaserMines < 1) {
            g_PlayerFuncs.SayText(pPlayer, "[ZP] [Shop] You don't have lasermines!\n");
            return HOOK_CONTINUE;
        }
            
        g_EngineFuncs.MakeVectors(pPlayer.pev.v_angle);
        Vector vecStart = pPlayer.GetGunPosition();
        TraceResult tr;
        g_Utility.TraceLine(vecStart, vecStart + g_Engine.v_forward * 320.f, dont_ignore_monsters, pPlayer.edict(), tr);
        if (tr.flFraction < 1.0f) {
            Vector vecMinePosition = Vector(tr.vecEndPos.x, tr.vecEndPos.y, tr.vecEndPos.z);
            Vector vecAngles = Math.VecToAngles(tr.vecPlaneNormal);
            float flYaw = vecAngles.y;
            float flForward = ZM_UTIL_Degree2Radians(flYaw);
            vecMinePosition = Vector(vecMinePosition.x + cos(flForward) * 8.f, vecMinePosition.y + sin(flForward) * 8.f, vecMinePosition.z);
            TraceResult allSafeTraceResult;
            g_Utility.TraceLine(vecMinePosition, vecMinePosition, ignore_monsters, dont_ignore_glass, null, allSafeTraceResult);
            Vector vecUpwards = Vector(vecMinePosition.x, vecMinePosition.y, vecMinePosition.z + 8.f);
            Vector vecDownwards = Vector(vecMinePosition.x, vecMinePosition.y, vecMinePosition.z - 8.f);
            if (allSafeTraceResult.flFraction != 1.0f || allSafeTraceResult.fAllSolid == 1) {
                g_Utility.TraceLine(vecMinePosition, vecUpwards, ignore_monsters, dont_ignore_glass, null, allSafeTraceResult);
                if (allSafeTraceResult.flFraction != 1.0f || allSafeTraceResult.fAllSolid == 1) {
                    g_Utility.TraceLine(vecMinePosition, vecDownwards, ignore_monsters, dont_ignore_glass, null, allSafeTraceResult);
                     if (allSafeTraceResult.flFraction != 1.0f || allSafeTraceResult.fAllSolid == 1) {
                        g_PlayerFuncs.SayText(pPlayer, "[ZP] [Shop] You can't place a lasermine there!\n");
                        return HOOK_CONTINUE;
                    } else {
                        vecMinePosition = vecDownwards;
                    }
                } else {
                    vecMinePosition = vecUpwards;
                }
            }
            CBaseEntity@ pEntity = g_EntityFuncs.Create("zpc_lasermine", vecMinePosition, vecAngles, true, null);
            @pEntity.pev.euser3 = pPlayer.edict();
            CLaserMine@ pLaserMine = cast<CLaserMine@>(CastToScriptClass(pEntity));
            pLaserMine.Spawn();
            bool bAlly = !g_abZombies[pPlayer.entindex()];
            pLaserMine.m_cMode = bAlly ? 0 : 1;
            g_EntityFuncs.DispatchSpawn(pEntity.edict());
            if (pData.m_flLastTakenLaserMineHealth != 1.f) {
                pEntity.pev.fuser3 = pData.m_flLastTakenLaserMineHealth;
                pData.m_flLastTakenLaserMineHealth = -1.f;
            }
            pData.m_iLaserMines--;
            ZM_UTIL_WriteShopPlayerData();
            pEntity.SetPlayerAlly(bAlly);
            pEntity.SetPlayerAllyDirect(bAlly);
        }
        
        return HOOK_HANDLED;
    }
    if (args.ArgC() > 0 && (args[0].Find("/zpdellaser") == 0)) {
        CBasePlayer@ pPlayer = _Params.GetPlayer();
        CShopMenuPlayerData@ pData = g_rglpShopMenuPlayerDataFastAccessor[pPlayer.entindex()];
        if (pData is null) {
            g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "[ZP] [Wrapper] Something went really wrong when we were looking up for your data...\n");
            return HOOK_CONTINUE;
        }
    
        if (!pPlayer.IsAlive()) {
            g_PlayerFuncs.SayText(pPlayer, "[ZP] [Shop] Why does a dead human needs a lasermine?\n");
            return HOOK_CONTINUE;
        }
        Observer@ pObserver = pPlayer.GetObserver();
        if (pObserver !is null && pObserver.IsObserver()) {
            g_PlayerFuncs.SayText(pPlayer, "[ZP] [Shop] Why does a dead human needs a lasermine?\n");
            return HOOK_CONTINUE;
        }
        
        g_EngineFuncs.MakeVectors(pPlayer.pev.v_angle);
        Vector vecStart = pPlayer.GetGunPosition();
        TraceResult tr;
        g_Utility.TraceLine(vecStart, vecStart + g_Engine.v_forward * 320.f, dont_ignore_monsters, pPlayer.edict(), tr);
        if (tr.pHit !is null) {
            CBaseEntity@ pEntity = g_EntityFuncs.Instance(tr.pHit);
            if (pEntity.GetClassname() != "zpc_lasermine") {
                g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "[ZP] [Shop] No lasermines found after your crosshair!\n");
            return HOOK_CONTINUE;
            }
            if (pEntity.pev.euser3 !is null) {
                CBaseEntity@ pOwner = g_EntityFuncs.Instance(pEntity.pev.euser3);
                if (pOwner is pPlayer) {
                    if (pData.m_iLaserMines >= 4) {
                        g_PlayerFuncs.SayText(pPlayer, "[ZP] [Shop] You can't carry more than four lasermines with yourself!\n");
                        return HOOK_CONTINUE;
                    }
                    pData.m_flLastTakenLaserMineHealth = pEntity.pev.health;
                    g_EntityFuncs.Remove(pEntity);
                    pData.m_iLaserMines++;
                    ZM_UTIL_WriteShopPlayerData();
                } else {
                    g_PlayerFuncs.SayText(pPlayer, "[ZP] [Shop] You're not the owner of this lasermine.\n");
                    return HOOK_CONTINUE;
                }
            }
        }
    }
    if (args.ArgC() > 0 && (args[0].Find("/zpnv") == 0)) {
        _Params.ShouldHide = true;
        CBasePlayer@ pPlayer = _Params.GetPlayer();
        int nPlayerIdx = pPlayer.entindex();

        if (g_abZombies[nPlayerIdx] && !g_abIsZombieFrozen[nPlayerIdx]) {
            g_abZombieTrickyNightVision[nPlayerIdx] = !g_abZombieTrickyNightVision[nPlayerIdx];
        } else {
            Observer@ pObserver = pPlayer.GetObserver();
            if (pObserver !is null && pObserver.IsObserver()) {
                g_abSpectatorTrickyNightVision[nPlayerIdx] = !g_abSpectatorTrickyNightVision[nPlayerIdx];
                return HOOK_HANDLED;
            }
            string szSteamID = g_EngineFuncs.GetPlayerAuthId(pPlayer.edict());
            CPlayerData@ pData = ZM_UTIL_GetPlayerDataBySteamID(szSteamID);
            if (pData.m_lpHumanClass.m_lpszName != "Mad Scientist") return HOOK_HANDLED;
            if (g_abCarriesNightvision[nPlayerIdx]) {
                g_PlayerFuncs.ScreenFade(pPlayer, g_vecGreenColour, 0.01, 0.1, 64, FFADE_IN);
                g_abCarriesNightvision[nPlayerIdx] = false;
            } else {
                g_PlayerFuncs.ScreenFade(pPlayer, g_vecGreenColour, 0.01, 0.5, 64, FFADE_OUT | FFADE_STAYOUT);
                g_abCarriesNightvision[nPlayerIdx] = true;
            }
        }
        
        return HOOK_HANDLED;
    }
    if (args.ArgC() > 0 && (args[0].Find("rtv") == 0)) {
        _Params.ShouldHide = true;
        CBasePlayer@ pPlayer = _Params.GetPlayer();
        int nPlayerIdx = pPlayer.entindex();
        if (!g_bIsThereAVoteGoingOn && g_abHasRockTheVoted[nPlayerIdx] && ZM_UTIL_GetRequiredRTVCount() > ZM_UTIL_CountAlreadyRockedPlayers()) {
            g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "[ZP] [RTV] You've already RTV'ed! We have " + string(ZM_UTIL_GetRequiredRTVCount() - ZM_UTIL_CountAlreadyRockedPlayers()) + " players left to start the vote.\n");
            return HOOK_HANDLED;
        }
        if (g_abHasRockTheVoted[nPlayerIdx] && g_bIsThereAVoteGoingOn) {
            if (g_lpVoteMenu !is null) {
                g_lpVoteMenu.Open(0, 0, pPlayer);
            }
            return HOOK_HANDLED;
        }
        if (!g_abHasRockTheVoted[nPlayerIdx]) {
            g_abHasRockTheVoted[nPlayerIdx] = true;
            g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[ZP] [RTV] " + string(pPlayer.pev.netname) + " wants to change the map! Type 'rtv' into chat to accept their offer.\n");
        }
        if (ZM_UTIL_GetRequiredRTVCount() <= ZM_UTIL_CountAlreadyRockedPlayers() && !g_bIsThereAVoteGoingOn) {
            g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[ZP] [RTV] Vote begins. You have 15 seconds left to vote! Type 'rtv' into chat to open the menu again.\n");
            g_bIsThereAVoteGoingOn = true;
            @g_lpfnCalculateVoteResults = g_Scheduler.SetTimeout("CalculateVoteResults", 15.f);
            if (g_lpVoteMenu !is null) {
                g_lpVoteMenu.Unregister();
                @g_lpVoteMenu = null;
            }
            if (g_lpVoteMenu is null) {
                @g_lpVoteMenu = CCustomTextMenu(ZM_VoteMenuCB, false);
                g_lpVoteMenu.MakeExitButtonTheSameColourAsTitle();
                g_lpVoteMenu.SetItemDelimeter(':');
                g_lpVoteMenu.SetTitle("Constantium's RTV");
                g_lpVoteMenu.AddItem("Take vote");
                array<string> aszMaps;
                aszMaps.resize(0);
                for (uint idx = 0; idx < 7; idx++) {
                    CVoteInProgressMap@ pCurrent = g_rglpVoteInProgressMaps[Math.RandomLong(0, g_rglpVoteInProgressMaps.length() - 1)];
                    if (pCurrent.m_lpszName == g_Engine.mapname) {
                        idx--;
                        continue;
                    }
                    if (pCurrent.m_lpszName == "choose_campaign_dynamic") {
                        idx--;
                        continue;
                    }
                    if (ZM_UTIL_DoesStringArrayHaveEntry(aszMaps, pCurrent.m_lpszName)) {
                        idx--;
                        continue;
                    }
                    aszMaps.insertLast(pCurrent.m_lpszName);
                }
                for (uint idx = 0; idx < aszMaps.length(); idx++) {
                    g_lpVoteMenu.AddItem(aszMaps[idx]);
                }
                g_lpVoteMenu.AddItem("choose_campaign_dynamic");
                g_lpVoteMenu.Register();
            }
            for (int idx = 1; idx <= g_Engine.maxClients; idx++) {
                CBasePlayer@ pPlayer2 = g_PlayerFuncs.FindPlayerByIndex(idx);
                if (pPlayer2 !is null && pPlayer2.IsConnected()) {
                    g_lpVoteMenu.Open(0, 0, pPlayer2);
                }
            }
        }
    }
    if (args.ArgC() > 0 && (args[0].Find("unrtv") == 0)) {
        _Params.ShouldHide = true;
        CBasePlayer@ pPlayer = _Params.GetPlayer();
        int nPlayerIdx = pPlayer.entindex();
        if (!g_abHasRockTheVoted[nPlayerIdx]) {
            g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "[ZP] [RTV] You haven't RTV'ed yet!\n");
            return HOOK_HANDLED;
        }
        if (g_bIsThereAVoteGoingOn) {
            g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "[ZP] [RTV] There's a vote in progress.\n");
            return HOOK_HANDLED;
        }
        g_abHasRockTheVoted[nPlayerIdx] = false;
        g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[ZP] [RTV] " + string(pPlayer.pev.netname) + " took their vote.\n");
    }
    
    return HOOK_CONTINUE;
}

HookReturnCode HOOKED_PlayerTakeDamage(DamageInfo@ _Info) {
    if (!g_bIsZM) return HOOK_CONTINUE;
    
    float flDamage = _Info.flDamage;
    
    _Info.bitsDamageType &= ~DMG_LAUNCH;
    //_Info.bitsDamageType &= ~DMG_KNOCKBACK;
    CBaseEntity@ pAttacker = _Info.pAttacker;
    string szAttackerSteamID = g_EngineFuncs.GetPlayerAuthId(pAttacker.edict());
    bool bIsAttackerAZombie = false;
    
    //A bug fix for the Damager plugin recreation - it didn't show the damage on some special game modes - 06/21/2024 ~ xWhitey
    bool bShouldInfect = true;
    
    if (ZM_UTIL_IsPlayerZombie(szAttackerSteamID)) {
        bIsAttackerAZombie = true;
        if (!_Info.pInflictor.IsPlayer()) bShouldInfect = false; //The zombie somehow got an rpg or something like that and dealt the damage not by using their claws, ignore that.
        if (g_bAssassinRound || g_bNightmareMode || g_bArmageddonMode || g_bDarkHarvestMode) {
            if (g_abIsAssassin[pAttacker.entindex()]) {
                if (pAttacker.IsPlayer()) {
                    CBasePlayer@ pPlayerAttacker = cast<CBasePlayer@>(pAttacker);
                    EHandle hActiveItem = pPlayerAttacker.m_hActiveItem;
                    if (hActiveItem.IsValid()) {
                        CBaseEntity@ pActiveItem = hActiveItem.GetEntity();
                        if (pActiveItem.GetClassname() == "weapon_zombieknife") {
                            if ((_Info.bitsDamageType & (DMG_SLASH | DMG_CLUB)) != 0 /* just to be sure */) {
                                _Info.flDamage = 150.f;
                            }
                        }
                    }
                }
            }
            bShouldInfect = false;
        }
        if (g_bSwarmRound || g_bNemesisRound || g_bNightmareMode || g_bArmageddonMode || g_bDarkHarvestMode) bShouldInfect = false; //We don't infect players in Swarm or Nemesis modes.
        if (g_bSurvivorRound || g_bSniperRound) bShouldInfect = false; //Well, the checks down will save us from headache, but it's better safe than sorry.
        CBaseEntity@ pVictimEntity = _Info.pVictim;
        if (pVictimEntity.pev.armorvalue > 0) bShouldInfect = false;
        if (bShouldInfect) {
            CPlayerData@ pAttackerData = ZM_UTIL_GetPlayerDataBySteamID(szAttackerSteamID);
            if (pAttackerData !is null && !g_abZombies[pVictimEntity.entindex()]) {
                if (pAttackerData.m_lpZombieClass.m_lpszName == "Leech") {
                    pAttacker.pev.health += 200.f;
                    pAttacker.pev.max_health += 200.f;
                }
            }
            CBasePlayer@ pVictim = cast<CBasePlayer@>(pVictimEntity);
            string szVictimSteamID = g_EngineFuncs.GetPlayerAuthId(pVictim.edict());
            if (!ZM_UTIL_IsPlayerZombie(szVictimSteamID) && ZM_UTIL_CountAlivePlayers() > 1) {
                _Info.flDamage = 0.f;
                CShopMenuPlayerData@ pData = g_rglpShopMenuPlayerDataFastAccessor[pAttacker.entindex()];
                if (pData !is null) {
                    pData.m_iAmmoPacks++;
                    ZM_UTIL_WriteShopPlayerData();
                }
                g_ahZombies.insertLast(EHandle(pVictim));
                HUDTextParams params;
                params.r1 = 255;
                params.g1 = 0;
                params.b1 = 0;
                params.a1 = 160;
                params.a2 = 160;
                params.x = 0.1f;
                params.y = -1.0f;
                params.effect = 0;
                params.fadeinTime = 0.5f;
                params.fadeoutTime = 0.5f;
                params.holdTime = 2.0f;
                params.channel = 2;
                
                g_PlayerFuncs.HudMessageAll(params, string(pVictim.pev.netname) + "'s brains were eaten by " + string(pAttacker.pev.netname) + "...");
                ZM_UTIL_TurnPlayerIntoAZombie(pVictim);
            }
        }
    } else {
        if (g_bSniperRound || g_bNightmareMode || g_bArmageddonMode || g_bDarkHarvestMode) {
            if (pAttacker.IsPlayer() && !g_abZombies[pAttacker.entindex()]) {
                CBasePlayer@ pPlayerAttacker = cast<CBasePlayer@>(pAttacker);
                EHandle hActiveItem = pPlayerAttacker.m_hActiveItem;
                if (hActiveItem.IsValid()) {
                    CBaseEntity@ pActiveItem = hActiveItem.GetEntity();
                    if (pActiveItem.GetClassname() == "weapon_sniperrifle") {
                        if ((_Info.bitsDamageType & DMG_BULLET) != 0 /* just to be sure */) {
                            _Info.flDamage = 3000.f;
                        }
                    }
                }
            }
        }
    }
    bool bIsVictimAZombie = false;
    CBaseEntity@ pVictim = _Info.pVictim;
    if (pVictim.IsPlayer()) {
        CBasePlayer@ pVictimPlayer = cast<CBasePlayer@>(pVictim);
        string szVictimSteamID = g_EngineFuncs.GetPlayerAuthId(pVictim.edict());
        if (ZM_UTIL_IsPlayerZombie(szVictimSteamID)) {
            bIsVictimAZombie = true;
            if (g_abIsZombieFrozen[pVictimPlayer.entindex()]) {
                _Info.flDamage = 0.f;
            }
            if ((_Info.bitsDamageType & DMG_FALL) != 0) {
                g_SoundSystem.EmitSoundDyn(pVictim.edict(), CHAN_BODY, "zombie_plague/zombie_fall1.wav", 1.0f, ATTN_NORM, 0, PITCH_NORM);
            } else {
                if (g_abIsNemesis[pVictim.entindex()]) {
                    ZM_UTIL_PlayRandomNemesisPainSound(pVictim.edict());
                } else {
                    ZM_UTIL_PlayRandomPainSound(pVictim.edict());
                }
            }
        }
    }
    CShopMenuPlayerData@ pData = g_rglpShopMenuPlayerDataFastAccessor[pAttacker.entindex()];
    if (pData !is null) {
        if (pVictim.IsPlayer() && pAttacker.Classify() != pVictim.Classify()) {
            pData.m_flDamageDealt += flDamage;
        }
        if (pData.m_flDamageDealt >= 450.f) {
            pData.m_iAmmoPacks++;
            ZM_UTIL_WriteShopPlayerData();
            pData.m_flDamageDealt = 0.f;
        }
    }
    if (pAttacker.IsPlayer() && pVictim.IsPlayer()) {
        if (pAttacker.Classify() == pVictim.Classify()) return HOOK_CONTINUE;
        if (_Info.flDamage <= 0.f) return HOOK_CONTINUE;
        if ((pVictim.pev.flags & FL_FAKECLIENT) == 0) {
            CBasePlayer@ pVictimPlayer = cast<CBasePlayer@>(pVictim);
            HUDTextParams params;
            params.r1 = 255;
            params.g1 = 0;
            params.b1 = 0;
            params.x = 0.45f;
            params.y = 0.50f;
            params.effect = 2;
            params.fxTime = 0.1f;
            params.fadeinTime = 0.1f;
            params.fadeoutTime = 0.1f;
            params.holdTime = 4.0f;
            params.channel = 1;
            
            g_PlayerFuncs.HudMessage(pVictimPlayer, params, string(int(_Info.flDamage)));
        }
        CBasePlayer@ pAttackerPlayer = cast<CBasePlayer@>(pAttacker);
        if ((pAttacker.pev.flags & FL_FAKECLIENT) == 0) {
            HUDTextParams params;
            params.r1 = 0;
            params.g1 = 100;
            params.b1 = 200;
            params.x = -1.0f;
            params.y = 0.55f;
            params.effect = 2;
            params.fxTime = 0.1f;
            params.fadeinTime = 0.02f;
            params.fadeoutTime = 0.02f;
            params.holdTime = 4.0f;
            params.channel = 1;
            
            g_PlayerFuncs.HudMessage(pAttackerPlayer, params, string(int(_Info.flDamage)));
        }
    }
    //Knockback
    if (pVictim is pAttacker || !pAttacker.IsAlive())
        return HOOK_CONTINUE;
    string szVictimSteamID = g_EngineFuncs.GetPlayerAuthId(pVictim.edict());
    if (ZM_UTIL_IsPlayerZombie(szAttackerSteamID) || !ZM_UTIL_IsPlayerZombie(szVictimSteamID))
        return HOOK_CONTINUE;
    if ((_Info.bitsDamageType & DMG_BULLET) == 0)
        return HOOK_CONTINUE;
    if (_Info.flDamage <= 0.f)
        return HOOK_CONTINUE;
    if (g_abIsNemesis[pVictim.entindex()])
        return HOOK_CONTINUE;
    if (g_abIsAssassin[pVictim.entindex()])
        return HOOK_CONTINUE;
    CPlayerData@ pPlayerData = ZM_UTIL_GetPlayerDataBySteamID(szVictimSteamID);
    if (pPlayerData is null)
        return HOOK_CONTINUE;
        
    g_Scheduler.SetTimeout("Post_HOOKED_PlayerTakeDamageAdv", 0.f, @pPlayerData, EHandle(pVictim), pVictim.pev.velocity, @_Info);
    
    return HOOK_CONTINUE;
}

void Post_HOOKED_PlayerTakeDamageAdv(CPlayerData@ _Data, EHandle _Victim, Vector _Velocity, DamageInfo@ _Info) {
    if (!_Victim.IsValid())
        return;
    CBaseEntity@ pEntity = _Victim.GetEntity();
    if (g_abIsNemesis[pEntity.entindex()])
        return;
    if (g_abIsAssassin[pEntity.entindex()])
        return;
    CZombieClass@ pKlass = _Data.m_lpZombieClass;
    pEntity.pev.velocity.x = _Velocity.x / ((pKlass.m_flKnockback / 100.f));
    pEntity.pev.velocity.y = _Velocity.y / ((pKlass.m_flKnockback / 100.f));
    //pEntity.pev.velocity.z = _Velocity.z;
}

HookReturnCode HOOKED_PlayerKilled(CBasePlayer@ _Victim, CBaseEntity@ _Attacker, int _WasGibbed) {
    if (!g_bIsZM) return HOOK_CONTINUE;
    
    string szVictimSteamID = g_EngineFuncs.GetPlayerAuthId(_Victim.edict());
    if (_Attacker.IsPlayer() && _Attacker !is _Victim && _Attacker.entindex() != _Victim.entindex()) {
        string szAttackerSteamID = g_EngineFuncs.GetPlayerAuthId(_Attacker.edict());
        bool bIsAHumanTank = ZM_UTIL_IsPlayerAHumanTank(szVictimSteamID);
        CShopMenuPlayerData@ pShopData = ZM_UTIL_FindShopMenuPlayerDataBySteamID(szAttackerSteamID);
        if (g_bSurvivorRound && bIsAHumanTank) {
            if (pShopData !is null) {
                pShopData.m_iAmmoPacks += 15;
                ZM_UTIL_WriteShopPlayerData();
                g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[ZP] " + string(_Attacker.pev.netname) + " got 15 ammo packs for killing Survivor!!\n");
            }
        } else if (g_bSniperRound && bIsAHumanTank) {
            if (pShopData !is null) {
                pShopData.m_iAmmoPacks += 25;
                ZM_UTIL_WriteShopPlayerData();
                g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[ZP] " + string(_Attacker.pev.netname) + " got 25 ammo packs for killing Sniper!!\n");
            }
        } else if (g_bNemesisRound && g_abIsNemesis[_Victim.entindex()]) {
            if (pShopData !is null) {
                pShopData.m_iAmmoPacks += 20;
                ZM_UTIL_WriteShopPlayerData();
                g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[ZP] " + string(_Attacker.pev.netname) + " got 20 ammo packs for killing Nemesis!!\n");
            }
        } else if (g_bAssassinRound && g_abIsAssassin[_Victim.entindex()]) {
            if (pShopData !is null) {
                pShopData.m_iAmmoPacks += 35;
                ZM_UTIL_WriteShopPlayerData();
                g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[ZP] " + string(_Attacker.pev.netname) + " got 35 ammo packs for killing Nemesis!!\n");
            }
        }
    }
    
    if (!g_bMatchStarted) return HOOK_CONTINUE;
    
    if (!ZM_UTIL_IsPlayerZombie(szVictimSteamID)) {
        HUDTextParams params;
        params.r1 = 255;
        params.g1 = 0;
        params.b1 = 0;
        params.a1 = 160;
        params.a2 = 160;
        params.x = 0.1f;
        params.y = -1.0f;
        params.effect = 0;
        params.fadeinTime = 0.5f;
        params.fadeoutTime = 0.5f;
        params.holdTime = 2.0f;
        params.channel = 2;
        
        string szAttackerSteamID = "";
        CBaseEntity@ pAttacker = _Attacker;
        if (pAttacker !is null && !pAttacker.IsPlayer()) {
            @pAttacker = g_EntityFuncs.Instance(pAttacker.pev.owner.vars);
            if (!pAttacker.IsPlayer()) {
                g_PlayerFuncs.HudMessageAll(params, string(_Victim.pev.netname) + "'s brains were eaten...");
                
                //return HOOK_CONTINUE;
            }
        } else if (pAttacker !is null && pAttacker.IsPlayer()) {
            szAttackerSteamID = g_EngineFuncs.GetPlayerAuthId(pAttacker.edict());
            if (ZM_UTIL_IsPlayerZombie(szAttackerSteamID)) {
                g_PlayerFuncs.HudMessageAll(params, string(_Victim.pev.netname) + "'s brains were eaten by " + string(pAttacker.pev.netname) + "...");
            }
        }
        
        if (ZM_UTIL_CountAlivePlayers() == 0) {
            MatchEnd();
        }
        
    } else {
        ZM_UTIL_PlayRandomDeathSound(_Victim.edict());
        ZM_UTIL_RemoveZombieBySteamID(szVictimSteamID);
        if (g_ahZombies.length() == 0) {
            MatchEnd();
        }
    }
    //if (_Victim is _Attacker)

    return HOOK_CONTINUE;
}

HookReturnCode HOOKED_PlayerPreThink(CBasePlayer@ _Player, uint& out _Flags) {
    if (!g_bIsZM) return HOOK_CONTINUE;
    
    int nPlayerIdx = _Player.entindex();
    
    Observer@ pObserver = _Player.GetObserver();
    if (pObserver !is null && pObserver.IsObserver() && g_abSpectatorTrickyNightVision[nPlayerIdx] && g_Engine.time - g_rgflLastSpectatorNightVisionUpdateTime[nPlayerIdx] > 0.1f) {
        Vector vecSrc = _Player.EyePosition();
        NetworkMessage nvon(MSG_ONE, NetworkMessages::SVC_TEMPENTITY, _Player.edict());
            nvon.WriteByte(TE_DLIGHT);
            nvon.WriteCoord(vecSrc.x);
            nvon.WriteCoord(vecSrc.y);
            nvon.WriteCoord(vecSrc.z);
            nvon.WriteByte(40);
            nvon.WriteByte(int(g_vecNightVisionColour.x));
            nvon.WriteByte(int(g_vecNightVisionColour.y));
            nvon.WriteByte(int(g_vecNightVisionColour.z));
            nvon.WriteByte(2);
            nvon.WriteByte(1);
        nvon.End();
        g_rgflLastSpectatorNightVisionUpdateTime[nPlayerIdx] = g_Engine.time;
    }
    
    if (!_Player.IsAlive()) {
        return HOOK_CONTINUE;
    }
    
    if (g_abZombies[nPlayerIdx]) { //Zombies specific code
        if (g_abIsZombieFrozen[nPlayerIdx] && _Player.pev.impulse == 100) { //Don't let the player toggle flashlight - this will disable screen fade effect. (NV toggle) ~ xWhitey
            _Player.pev.impulse = 0;
        }
        if (_Player.pev.impulse == 100) {
            g_abZombieTrickyNightVision[nPlayerIdx] = !g_abZombieTrickyNightVision[nPlayerIdx];
            _Player.pev.impulse = 0;
        }
        
        CPlayerData@ pData = g_rglpFastPlayerDataAccessor[nPlayerIdx];
        if (pData is null) {
            string szSteamID = g_EngineFuncs.GetPlayerAuthId(_Player.edict());
            @pData = ZM_UTIL_GetPlayerDataBySteamID(szSteamID);
            if (pData is null) {
                @pData = CPlayerData(szSteamID);
                g_rglpPlayerDatas.insertLast(@pData);
            }
            @g_rglpFastPlayerDataAccessor[nPlayerIdx] = @pData;
        }
        
        //https://github.com/FWGS/regamedll/blob/ac303f29ecf1324bc6aeb8f1011df481af7bbf21/regamedll/pm_shared/pm_shared.cpp#L2408
        if ((g_bAssassinRound || g_bDefaultRound || g_bNightmareMode) && (pData.m_flLastLongjumpTime + 2.5f < g_Engine.time)) {
            if (g_abIsAssassin[nPlayerIdx] /* assasin class has longjump inbuilt */ || (_Player.pev.max_health == (pData.m_lpZombieClass.m_flHealth * 2.f)) /* <- check if the player is the first zombie */) {
                if (((_Player.pev.bInDuck != 0) || (_Player.pev.flags & FL_DUCKING) != 0) && (_Player.pev.button & IN_JUMP) != 0 && (_Player.pev.flags & FL_ONGROUND) != 0) {
                    // Adjust for super long jump module
                    // UNDONE -- note this should be based on forward angles, not current velocity.
                    if ((_Player.pev.button & IN_DUCK) != 0 && (_Player.pev.flDuckTime > 0.f) && _Player.pev.velocity.Length() > 50.f) {
                        //_Player.pev.punchangle.x = -5.f; //No. There's no such thing in the original ZP, so I decided to remove it too. ~ xWhitey
                        
                        float sy = sin(ZM_UTIL_Degree2Radians(_Player.pev.v_angle.y));

                        float cp = cos(ZM_UTIL_Degree2Radians(_Player.pev.v_angle.x));
                        float cy = cos(ZM_UTIL_Degree2Radians(_Player.pev.v_angle.y));
                        
                        Vector vecForward(cp * cy, cp * sy, 0.f);
                        vecForward = vecForward.Normalize();

                        for (int i = 0; i < 2; i++) {
                            //I could've used "g_Engine.v_forward" here but I'm aware of race conditioning, so better safe than sorry. ~ xWhitey
                            _Player.pev.velocity[i] = vecForward[i] * 350.f /* <- our PLAYER_LONGJUMP_SPEED */ * 1.6f;
                        }
                    
                       _Player.pev.velocity.z += 50.f;
                       pData.m_flLastLongjumpTime = g_Engine.time;
                       _Player.pev.button &= ~IN_JUMP;
                    }
                }
            }
        }
        
        if (pData.m_flLastLongjumpTime + 1.5f < g_Engine.time) {
            if (_Player.pev.velocity.x > 450.f) {
                _Player.pev.velocity.x = 450.f;
            }
            
            if (_Player.pev.velocity.y > 450.f) {
                _Player.pev.velocity.y = 450.f;
            }
            
            if (_Player.pev.velocity.Length2D() > 450.f) {
                _Player.pev.velocity.x *= 0.7f;
                _Player.pev.velocity.y *= 0.7f;
            }
        }
    } else {
        if (g_abIsAssassin[nPlayerIdx]) {
            if (_Player.pev.maxspeed != 800.f) {
                _Player.pev.maxspeed = 800.f;
            }
            return HOOK_CONTINUE;
        }

        if (_Player.pev.velocity.x > 450.f) {
            _Player.pev.velocity.x = 450.f;
        }
        
        if (_Player.pev.velocity.y > 450.f) {
            _Player.pev.velocity.y = 450.f;
        }
        
        if (_Player.pev.velocity.Length2D() > 450.f) {
            _Player.pev.velocity.x *= 0.7f;
            _Player.pev.velocity.y *= 0.7f;
        }
    }
    
    return HOOK_CONTINUE;
}

HookReturnCode HOOKED_PlayerPostThink(CBasePlayer@ _Player) {
    if (!g_bIsZM) return HOOK_CONTINUE;
    
    if (!_Player.IsAlive()) return HOOK_CONTINUE;

    int nPlayerIdx = _Player.entindex();
    EHandle hActiveItem = _Player.m_hActiveItem;
    if (hActiveItem.IsValid() && !g_abZombies[nPlayerIdx]) {
        CBasePlayerWeapon@ pActiveItem = cast<CBasePlayerWeapon@>(hActiveItem.GetEntity());
        if (pActiveItem !is null) {
            string szClassname = string(pActiveItem.pev.classname);
            array<EHandle>@ pThisPlayerArms = @g_aapBoughtArms[nPlayerIdx];
            bool bShouldGiveAmmo = true;
            if (pThisPlayerArms.length() != 0) {
                for (uint idx = 0; idx < pThisPlayerArms.length(); idx++) {
                    EHandle hWeapon = pThisPlayerArms[idx];
                    if (!hWeapon.IsValid()) {
                        pThisPlayerArms.removeAt(idx);
                        continue;
                    }
                    CBaseEntity@ pEntity = hWeapon.GetEntity();
                    CBasePlayerWeapon@ pWeapon = cast<CBasePlayerWeapon@>(pEntity);
                    if (pWeapon is null) {
                        pThisPlayerArms.removeAt(idx);
                        continue;
                    }
                    if (pWeapon is pActiveItem || pWeapon.entindex() == pActiveItem.entindex() || pWeapon.GetClassname() == pActiveItem.GetClassname()) {
                        bShouldGiveAmmo = g_abHasBoughtInfiniteAmmo[nPlayerIdx];
                        break;
                    }
                }
            }
            if (bShouldGiveAmmo && szClassname.Find("grenade") == String::INVALID_INDEX) {
                int iPrimaryIdx = pActiveItem.PrimaryAmmoIndex();
                if (iPrimaryIdx != -1) {
                    if (g_abHasBoughtInfiniteAmmo[nPlayerIdx] || g_bSniperRound || g_bSurvivorRound) {
                        pActiveItem.m_iClip = pActiveItem.iMaxClip();
                    }
                    _Player.m_rgAmmo(iPrimaryIdx, _Player.GetMaxAmmo(iPrimaryIdx));
                }
            }
        }
    }
    
    if (g_rgflLastZombieSentenceTime[nPlayerIdx] <= g_Engine.time) {
        string szSteamID = g_EngineFuncs.GetPlayerAuthId(_Player.edict());
        if (ZM_UTIL_IsPlayerZombie(szSteamID)) {
            g_rgflLastZombieSentenceTime[nPlayerIdx] = g_Engine.time + float(Math.RandomLong(15, 40));
            ZM_UTIL_PlayRandomNihilanthQuote(_Player.edict());
        } else {
            g_rgflLastZombieSentenceTime[nPlayerIdx] = g_Engine.time + 9999.f;
        }
    }
    
    if (g_abIsAssassin[nPlayerIdx]) {
        return HOOK_CONTINUE;
    }
    
    if (g_abZombies[nPlayerIdx]) {
        CPlayerData@ pData = g_rglpFastPlayerDataAccessor[nPlayerIdx];
        if (pData.m_flLastLongjumpTime + 1.5f < g_Engine.time) {
            if (_Player.pev.velocity.x > 450.f) {
                _Player.pev.velocity.x = 450.f;
            }
                
            if (_Player.pev.velocity.y > 450.f) {
                _Player.pev.velocity.y = 450.f;
            }
                
            if (_Player.pev.velocity.Length2D() > 450.f) {
                _Player.pev.velocity.x *= 0.7f;
                _Player.pev.velocity.y *= 0.7f;
            }
        }
        
        return HOOK_CONTINUE;
    }

    if (_Player.pev.velocity.x > 450.f) {
        _Player.pev.velocity.x = 450.f;
    }
    
    if (_Player.pev.velocity.y > 450.f) {
        _Player.pev.velocity.y = 450.f;
    }
    
    if (_Player.pev.velocity.Length2D() > 450.f) {
        _Player.pev.velocity.x *= 0.7f;
        _Player.pev.velocity.y *= 0.7f;
    }

    return HOOK_CONTINUE;
}

HookReturnCode HOOKED_ClientDisconnect(CBasePlayer@ _Player) {
    if (!g_bIsZM) return HOOK_CONTINUE;

    int nPlayerIdx = _Player.entindex();
    if (g_rglpShopMenuPlayerDataFastAccessor[nPlayerIdx] !is null) {
        @g_rglpShopMenuPlayerDataFastAccessor[nPlayerIdx] = null;
    }
    if (g_rglpFastPlayerDataAccessor[nPlayerIdx] !is null) {
        @g_rglpFastPlayerDataAccessor[nPlayerIdx] = null;
    }
    if (g_lpfnCountPlayersOnClientDisconnected !is null && !g_lpfnCountPlayersOnClientDisconnected.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(g_lpfnCountPlayersOnClientDisconnected);
        @g_lpfnCountPlayersOnClientDisconnected = null;
    }
    
    @g_lpfnCountPlayersOnClientDisconnected = g_Scheduler.SetTimeout("CountPlayersOnClientDisconnected", 2.0f);

    return HOOK_CONTINUE;
}

void CountPlayersOnClientDisconnected() {
    if (ZM_UTIL_CountPlayers() == 0) {
        g_EngineFuncs.ServerCommand("mp_nextmap_cycle choose_campaign_dynamic\n");
        g_EngineFuncs.ServerExecute();
        CBaseEntity@ pGameEnd = g_EntityFuncs.CreateEntity("game_end");
        pGameEnd.Use(null, null, USE_TOGGLE);
    }
}

void Notifier() {
    if (g_lpfnNotifier !is null && !g_lpfnNotifier.HasBeenRemoved()) {
        g_Scheduler.RemoveTimer(g_lpfnNotifier);
        @g_lpfnNotifier = null;
    }
    
    if (!g_bIsZM) return;

    g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "**** Zombie Plague BETA ****\n");
    g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[ZP] Type '.zp_menu' in the console to open the game menu (or use '/zpmenu' in the chat instead)\n");
    g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[ZP] Type '.zp_nightvision' in the console to toggle nightvision (or use '/zpnv' in the chat instead)\n");
    g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, "[ZP] Press E (+use) to swap places with a teammate\n");
    
    @g_lpfnNotifier = g_Scheduler.SetTimeout("Notifier", float(Math.RandomLong(90, 300)));
}

CClientCommand _nightvision("zp_nightvision", "Toggle nightvision", @ZM_CMD_Nightvision);

void ZM_CMD_Nightvision(const CCommand@ _Args) {
    CBasePlayer@ pPlayer = g_ConCommandSystem.GetCurrentPlayer();
    if (!g_bIsZM) {
        g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTCONSOLE, "Unknown command: .zp_nightvision\n");
        return;
    }
    
    int nPlayerIdx = pPlayer.entindex();
    

    if (g_abZombies[nPlayerIdx]) {
        if (!g_abIsZombieFrozen[nPlayerIdx])
            g_abZombieTrickyNightVision[nPlayerIdx] = !g_abZombieTrickyNightVision[nPlayerIdx];
    } else {
        Observer@ pObserver = pPlayer.GetObserver();
        if (pObserver !is null && pObserver.IsObserver()) {
            g_abSpectatorTrickyNightVision[nPlayerIdx] = !g_abSpectatorTrickyNightVision[nPlayerIdx];
            return;
        }
        string szSteamID = g_EngineFuncs.GetPlayerAuthId(pPlayer.edict());
        CPlayerData@ pData = ZM_UTIL_GetPlayerDataBySteamID(szSteamID);
        if (pData.m_lpHumanClass.m_lpszName != "Mad Scientist") return;
        if (g_abCarriesNightvision[nPlayerIdx]) {
            g_PlayerFuncs.ScreenFade(pPlayer, g_vecGreenColour, 0.01, 0.1, 64, FFADE_IN);
            g_abCarriesNightvision[nPlayerIdx] = false;
        } else {
            g_PlayerFuncs.ScreenFade(pPlayer, g_vecGreenColour, 0.01, 0.5, 64, FFADE_OUT | FFADE_STAYOUT);
            g_abCarriesNightvision[nPlayerIdx] = true;
        }
    }
}

CClientCommand _start("zp_start", "Try starting a match", @ZM_CMD_Start);

void ZM_CMD_Start(const CCommand@ _Args) {
    CBasePlayer@ pPlayer = g_ConCommandSystem.GetCurrentPlayer();
    if (!g_bIsZM) {
        g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTCONSOLE, "Unknown command: .zp_start\n");
        return;
    }

    @g_lpfnTryStartingAMatch = g_Scheduler.SetTimeout("TryStartingAMatch", 0.0f);
}

CClientCommand _menu("zp_menu", "Open game menu", @ZM_CMD_Menu);

void ZM_CMD_Menu(const CCommand@ _Args) {
    CBasePlayer@ pPlayer = g_ConCommandSystem.GetCurrentPlayer();
    if (!g_bIsZM) {
        g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTCONSOLE, "Unknown command: .zp_menu\n");
        return;
    }
    
    if (g_lpMainMenu is null) {
        @g_lpMainMenu = CCustomTextMenu(ZM_MainMenuCB, false);
        g_lpMainMenu.MakeExitButtonTheSameColourAsTitle();
        g_lpMainMenu.SetItemDelimeter(':');
        g_lpMainMenu.SetTitle("Constantium's ZombieMod");
        g_lpMainMenu.AddItem("Buy weapons");
        g_lpMainMenu.AddItem("Buy Extra Items");
        g_lpMainMenu.AddItem("Choose Zombie Class");
        g_lpMainMenu.AddItem("Choose Human Class");
        g_lpMainMenu.AddItem("Manage buyables");
        g_lpMainMenu.AddItem("Admin Menu");
        g_lpMainMenu.Register();
    }
        
    g_lpMainMenu.Open(0, 0, pPlayer);
}
