#pragma semicolon 1
//#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>

#include <cw3-attributes-redux>
#include <cw3-core-redux>
#include <tf2attributes>

#define MAX_ENTITY_LIMIT 2048
#define MAX_BUTTONS 25

#define RAG_GIBBED			(1<<0)
#define RAG_BURNING			(1<<1)
#define RAG_ELECTROCUTED	(1<<2)
#define RAG_FEIGNDEATH		(1<<3)
#define RAG_WASDISGUISED	(1<<4)
#define RAG_BECOMEASH		(1<<5)
#define RAG_ONGROUND		(1<<6)
#define RAG_CLOAKED			(1<<7)
#define RAG_GOLDEN			(1<<8)
#define RAG_ICE				(1<<9)
#define RAG_CRITONHARDCRIT	(1<<10)
#define RAG_HIGHVELOCITY	(1<<11)
#define RAG_NOHEAD			(1<<12)

int iLastButtons[MAXPLAYERS + 1];
int g_iLaserMaterial;
int g_iHaloMaterial;

bool g_bAttribute_FireChairs[MAXPLAYERS + 1][MAXSLOTS + 1];
float g_fFireChairDelay[MAXPLAYERS + 1];

bool g_bAttribute_FireBarrage[MAXPLAYERS + 1][MAXSLOTS + 1];
bool g_bIsSpawnedRocket[MAX_ENTITY_LIMIT + 1];
Handle g_hSDKSetRocketDamage;

bool g_bAttribute_HomingRockets[MAXPLAYERS + 1][MAXSLOTS + 1];
bool g_bIsHomingRocket[MAX_ENTITY_LIMIT + 1];

bool g_bAttribute_PrelaunchedRockets[MAXPLAYERS + 1][MAXSLOTS + 1];
ArrayList g_RocketOrigins[MAXPLAYERS + 1];
ArrayList g_RocketAngles[MAXPLAYERS + 1];
bool g_bIsFiringRockets[MAXPLAYERS + 1];

bool g_bAttribute_HealOnPillExplode[MAXPLAYERS + 1][MAXSLOTS + 1];

bool g_bAttribute_RocketDetonator[MAXPLAYERS + 1][MAXSLOTS + 1];

bool g_bAttribute_LaunchBackwardsFast[MAXPLAYERS + 1][MAXSLOTS + 1];

bool g_bAttribute_ExplodeOnLandWithJetpack[MAXPLAYERS + 1][MAXSLOTS + 1];
ArrayList g_Detonators[MAXPLAYERS + 1];

bool g_bAttribute_FreezeEnemiesNearArrow[MAXPLAYERS + 1][MAXSLOTS + 1];

public Plugin myinfo =
{
	name = "[TF2] Weapons Express",
	author = "Drixevel",
	description = "Custom weapon attributes by yours truly.",
	version = "1.0.0",
	url = "https://drixevel.dev/"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	HookEvent("rocketpack_landed", Event_OnRocketPackLanding);
	HookEvent("arrow_impact", Event_OnArrowImpact);

	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetVirtual(130);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	g_hSDKSetRocketDamage = EndPrepSDKCall();

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
	}

	for (int i = MaxClients; i <= MAX_ENTITY_LIMIT; i++)
	{
		if (IsValidEntity(i))
		{
			char sClassname[256];
			GetEntityClassname(i, sClassname, sizeof(sClassname));
			OnEntityCreated(i, sClassname);
		}
	}
}

public void Event_OnRocketPackLanding(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	int secondary = GetPlayerWeaponSlot(client, 1);
	int slot = GetWeaponSlot(client, secondary);

	if (slot == -1)
	{
		return;
	}

	if (g_bAttribute_ExplodeOnLandWithJetpack[client][slot])
	{
		float vecOrigin[3];
		GetClientAbsOrigin(client, vecOrigin);

		CreateExplosion(vecOrigin);
		//TF2_CreateExplosion(vecOrigin, 99999.0, 5000.0, 5000.0, client, secondary, GetClientTeam(client) == 2 ? 3 : 2);

		int ragdoll = CreateEntityByName("tf_ragdoll");

		if (IsValidEdict(ragdoll))
		{
			SetEntPropVector(ragdoll, Prop_Send, "m_vecRagdollOrigin", vecOrigin);
			SetEntProp(ragdoll, Prop_Send, "m_iPlayerIndex", client);
			SetEntPropVector(ragdoll, Prop_Send, "m_vecForce", NULL_VECTOR);
			SetEntPropVector(ragdoll, Prop_Send, "m_vecRagdollVelocity", NULL_VECTOR);
			SetEntProp(ragdoll, Prop_Send, "m_bGib", 1);

			DispatchSpawn(ragdoll);

			CreateTimer(0.1, RemoveBody, client);
			CreateTimer(15.0, RemoveGibs, ragdoll);
		}

		TF2_Particle("fluidSmokeExpl_ring_mvm", vecOrigin, client);
		FakeClientCommand(client, "kill");
	}
}

public Action RemoveBody(Handle Timer, any iClient)
{
	int iBodyRagdoll = GetEntPropEnt(iClient, Prop_Send, "m_hRagdoll");

	if (IsValidEdict(iBodyRagdoll))
	{
		RemoveEdict(iBodyRagdoll);
	}

	return Plugin_Continue;
}

public Action RemoveGibs(Handle Timer, any iEnt)
{
	if (IsValidEntity(iEnt))
	{
		char sClassname[64];
		GetEdictClassname(iEnt, sClassname, sizeof(sClassname));

		if (StrEqual(sClassname, "tf_ragdoll", false))
		{
			RemoveEdict(iEnt);
		}
	}

	return Plugin_Continue;
}

public void Event_OnArrowImpact(Event event, const char[] name, bool dontBroadcast)
{
	int client = event.GetInt("shooter");

	int slot = GetActiveWeaponSlot(client);

	if (slot == -1)
	{
		return;
	}

	if (g_bAttribute_FreezeEnemiesNearArrow[client][slot])
	{
		float vecOrigin[3];
		vecOrigin[0] = event.GetFloat("bonePositionX");
		vecOrigin[1] = event.GetFloat("bonePositionY");
		vecOrigin[2] = event.GetFloat("bonePositionZ");

		float vecPlayer[3];
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientConnected(i) || !IsClientInGame(i) || !IsPlayerAlive(i) || TF2_GetClientTeam(i) == TF2_GetClientTeam(client))
			{
				continue;
			}

			GetClientAbsOrigin(i, vecPlayer);

			if (GetVectorDistance(vecOrigin, vecPlayer) > 500.0)
			{
				continue;
			}

			ForcePlayerSuicide(i);
			TF2_RemoveRagdoll(client);

			RequestFrame(Frame_DelayRagdollUpdates, GetClientUserId(i));
		}
	}
}

public void Frame_DelayRagdollUpdates(any data)
{
	int client = GetClientOfUserId(data);

	if (client > 0)
	{
		TF2_SpawnRagdoll(client, 10.0, RAG_ICE);
	}
}

public void OnMapStart()
{
	g_iLaserMaterial = PrecacheModel("materials/sprites/laserbeam.vmt");
	g_iHaloMaterial = PrecacheModel("materials/sprites/halo01.vmt");

	//PrecacheModel("models/props_manor/chair_01.mdl");
	PrecacheModel("models/props_spytech/terminal_chair.mdl");

	PrecacheSound("ui/hitsound_menu_note8.wav");
	PrecacheSound("passtime/pass_to_me.wav");

	PrecacheSound("misc/halloween/spell_overheal.wav");

	PrecacheSound("weapons/stickybomblauncher_det.wav");
	PrecacheSound("weapons/grappling_hook_impact_default.wav");
}

public void OnConfigsExecuted()
{
	ServerCommand("sm_reloadweapons");
}

public void OnPluginEnd()
{

}

public Action CW3_OnAddAttribute(int slot, int client, const char[] attrib, const char[] plugin, const char[] value, bool whileActive)
{
	if (!StrEqual(plugin, "shadersallen-attributes"))
	{
		return Plugin_Continue;
	}

	Action action;

	if (StrEqual(attrib, "fire chairs as bullets"))
	{
		g_bAttribute_FireChairs[client][slot] = view_as<bool>(StringToInt(value));
		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "fire barrage of rockets"))
	{
		g_bAttribute_FireBarrage[client][slot] = view_as<bool>(StringToInt(value));
		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "homing rockets"))
	{
		g_bAttribute_HomingRockets[client][slot] = view_as<bool>(StringToInt(value));
		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "prelaunched rockets"))
	{
		g_bAttribute_PrelaunchedRockets[client][slot] = view_as<bool>(StringToInt(value));

		delete g_RocketOrigins[client];
		g_RocketOrigins[client] = new ArrayList(3);

		delete g_RocketAngles[client];
		g_RocketAngles[client] = new ArrayList(3);

		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "heal on pill explode"))
	{
		g_bAttribute_HealOnPillExplode[client][slot] = view_as<bool>(StringToInt(value));

		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "rocket detonator"))
	{
		g_bAttribute_RocketDetonator[client][slot] = view_as<bool>(StringToInt(value));

		delete g_Detonators[client];
		g_Detonators[client] = new ArrayList();

		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "launch backwards fast"))
	{
		g_bAttribute_LaunchBackwardsFast[client][slot] = view_as<bool>(StringToInt(value));

		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "explode on land with jetpack"))
	{
		g_bAttribute_ExplodeOnLandWithJetpack[client][slot] = view_as<bool>(StringToInt(value));

		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "freeze enemies near arrows"))
	{
		g_bAttribute_FreezeEnemiesNearArrow[client][slot] = view_as<bool>(StringToInt(value));

		action = Plugin_Handled;
	}

	return action;
}

public void CW3_OnWeaponSpawned(int weapon, int slot, int client)
{

}

public void CW3_OnWeaponRemoved(int slot, int client)
{
	g_bAttribute_FireChairs[client][slot] = false;
	g_bAttribute_FireBarrage[client][slot] = false;
	g_bAttribute_HomingRockets[client][slot] = false;

	if (g_bAttribute_PrelaunchedRockets[client][slot])
	{
		delete g_RocketOrigins[client];
		delete g_RocketAngles[client];
		g_bAttribute_PrelaunchedRockets[client][slot] = false;
	}

	g_bAttribute_HealOnPillExplode[client][slot] = false;
	g_bAttribute_RocketDetonator[client][slot] = false;
	g_bAttribute_LaunchBackwardsFast[client][slot] = false;

	if (g_bAttribute_ExplodeOnLandWithJetpack[client][slot])
	{
		delete g_Detonators[client];
		g_bAttribute_ExplodeOnLandWithJetpack[client][slot] = false;
	}

	g_bAttribute_FreezeEnemiesNearArrow[client][slot] = false;
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	bool changed;

	int slot = GetActiveWeaponSlot(attacker);

	if (slot == -1)
	{
		return Plugin_Continue;
	}

	if (g_bAttribute_FireChairs[attacker][slot] && damagetype & DMG_BULLET)
	{
		damage = 0.0;
		changed = true;
	}

	if (g_bAttribute_HealOnPillExplode[attacker][slot] && GetClientTeam(victim) != GetClientTeam(attacker))
	{
		damage = (damagetype & DMG_BLAST) ? 0.0 : (2.5 * damage);
		changed = true;
	}

	return changed ? Plugin_Changed : Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	int slot = GetActiveWeaponSlot(client);
	int active = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

	for (int i = 0; i < MAX_BUTTONS; i++)
	{
		int button = (1 << i);

		if ((buttons & button))
		{
			if (!(iLastButtons[client] & button))
			{
				OnButtonPress(client, button, slot, active);
			}
		}
		else if ((iLastButtons[client] & button))
		{
			OnButtonRelease(client, button, slot, active);
		}
	}

	iLastButtons[client] = buttons;
	return Plugin_Continue;
}

void OnButtonPress(int client, int button, int slot, int active)
{
	if (client && button && slot && active)
	{

	}
}

void OnButtonRelease(int client, int button, int slot, int active)
{
	if (slot == -1)
	{
		return;
	}

	if (button & IN_ATTACK2)
	{
		if (g_bAttribute_PrelaunchedRockets[client][slot] && g_RocketOrigins[client].Length > 0)
		{
			g_bIsFiringRockets[client] = true;

			for (int i = 0; i < g_RocketOrigins[client].Length; i++)
			{
				float vecOrigin[3];
				g_RocketOrigins[client].GetArray(i, vecOrigin, sizeof(vecOrigin));

				float vecAngles[3];
				g_RocketAngles[client].GetArray(i, vecAngles, sizeof(vecAngles));

				TF2_FireProjectile(vecOrigin, vecAngles, "tf_projectile_rocket", client, GetClientTeam(client), 1100.0, 90.0, view_as<bool>(GetRandomInt(0, 1)), active);
			}

			EmitSoundToClient(client, "passtime/pass_to_me.wav");
			SpeakResponseConceptDelayed(client, "TLK_PLAYER_CHEERS", 0.3);

			g_RocketOrigins[client].Clear();
			g_RocketAngles[client].Clear();

			g_bIsFiringRockets[client] = false;
		}

		if (g_bAttribute_RocketDetonator[client][slot] && g_Detonators[client].Length > 0)
		{
			EmitSoundToClient(client, "weapons/stickybomblauncher_det.wav");
			SpeakResponseConceptDelayed(client, "TLK_PLAYER_CHEERS", 0.6);

			CreateTimer(0.2, Timer_DetonateRockets, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action Timer_DetonateRockets(Handle timer, any data)
{
	int client = GetClientOfUserId(data);

	if (client < 1 || !IsClientConnected(client) || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return Plugin_Stop;
	}

	int rocket; float vecOrigin[3];
	for (int i = 0; i < g_Detonators[client].Length; i++)
	{
		rocket = EntRefToEntIndex(g_Detonators[client].Get(i));

		if (IsValidEntity(rocket))
		{
			GetEntPropVector(rocket, Prop_Send, "m_vecOrigin", vecOrigin);
			//TF2_CreateExplosion(vecOrigin, 99999.0, 2500.0, 1000.0, client, rocket, GetClientTeam(client) == 2 ? 3 : 2, "cinefx_goldrush", "items/cart_explode.wav", 200.0, 300.0, 3.0);
			CreateExplosion(vecOrigin);

			AcceptEntityInput(rocket, "Kill");
		}
	}

	g_Detonators[client].Clear();
	return Plugin_Stop;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "tf_projectile_rocket"))
	{
		SDKHook(entity, SDKHook_SpawnPost, OnRocketSpawnPost);
	}
	else if (StrEqual(classname, "tf_projectile_pipe"))
	{
		SDKHook(entity, SDKHook_Spawn, OnPipeSpawn);
		SDKHook(entity, SDKHook_SpawnPost, OnPipeSpawnPost);
	}
}

public Action OnPipeSpawn(int entity)
{
	SetEntProp(entity, Prop_Data, "m_iInitialTeamNum", 0);
	SetEntProp(entity, Prop_Send, "m_iTeamNum", 0);
	return Plugin_Continue;
}

public void OnPipeSpawnPost(int entity)
{
	SetEntProp(entity, Prop_Data, "m_iInitialTeamNum", 0);
	SetEntProp(entity, Prop_Send, "m_iTeamNum", 0);
}

public void OnEntityDestroyed(int entity)
{
	if (entity < MaxClients)
	{
		return;
	}

	g_bIsHomingRocket[entity] = false;

	char sClassname[32];
	GetEntityClassname(entity, sClassname, sizeof(sClassname));

	if (StrEqual(sClassname, "tf_projectile_pipe"))
	{
		int owner = GetEntPropEnt(entity, Prop_Data, "m_hThrower");

		if (owner > 0)
		{
			int slot = GetActiveWeaponSlot(owner);
			int team = GetClientTeam(owner);

			if (g_bAttribute_HealOnPillExplode[owner][slot])
			{
				float vecOrigin[3];
				GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vecOrigin);

				float vecBuffer[3];
				for (int i = 1; i <= MaxClients; i++)
				{
					if (!IsClientInGame(i) || !IsPlayerAlive(i))
					{
						continue;
					}

					GetClientAbsOrigin(i, vecBuffer);

					if (GetVectorDistance(vecOrigin, vecBuffer) > 250.0)
					{
						continue;
					}

					if (team == GetClientTeam(i))
					{
						TF2_AddCondition(i, TFCond_InHealRadius, 3.0, owner);
						TF2_AddPlayerHealth(i, 35);
					}
					else
					{
						TF2_MakeBleed(i, owner, 3.0);
					}
				}

				CreateParticle(team == 2 ? "hell_megaheal_red_shower" : "hell_megaheal_blue_shower", vecOrigin, 5.0);
				EmitSoundToAll("misc/halloween/spell_overheal.wav", entity);
			}
		}
	}
}

public void OnRocketSpawnPost(int entity)
{
	int shooter = -1;
	if ((shooter = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity")) < 1 || !IsClientConnected(shooter) || !IsClientInGame(shooter))
	{
		return;
	}

	int slot = GetActiveWeaponSlot(shooter);

	if (slot > -1)
	{
		g_bIsHomingRocket[entity] = g_bAttribute_HomingRockets[shooter][slot];

		if (g_bAttribute_FireBarrage[shooter][slot])
		{
			for (int i = 0; i < 20; i++)
			{
				CreateTimer((0.1 * float(i)), Timer_SpawnRocket, shooter);
			}

			if (g_bIsSpawnedRocket[entity])
			{
				g_bIsSpawnedRocket[entity] = false;
			}
			else
			{
				AcceptEntityInput(entity, "Kill");
			}
		}

		if (g_bAttribute_PrelaunchedRockets[shooter][slot] && !g_bIsFiringRockets[shooter])
		{
			float vecOrigin[3];
			GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vecOrigin);
			g_RocketOrigins[shooter].PushArray(vecOrigin);

			float vecAngles[3];
			GetEntPropVector(entity, Prop_Data, "m_angRotation", vecAngles);
			g_RocketAngles[shooter].PushArray(vecAngles);

			AcceptEntityInput(entity, "Kill");
			EmitSoundToClient(shooter, "ui/hitsound_menu_note8.wav", SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, (100 + (g_RocketOrigins[shooter].Length * 3)));
		}

		if (g_bAttribute_RocketDetonator[shooter][slot])
		{
			AcceptEntityInput(entity, "Kill");

			float vecOrigin[3];
			GetClientEyePosition(shooter, vecOrigin);

			float vecAngles[3];
			GetClientEyeAngles(shooter, vecAngles);

			VectorAddRotatedOffset(vecAngles, vecOrigin, view_as<float>({50.0, 0.0, 0.0}));

			float vecLook[3];
			GetClientLookOrigin(shooter, vecLook, true, 0.0);

			int rocket = CreateEntityByName("prop_physics_override");

			if (IsValidEntity(rocket))
			{
				DispatchKeyValue(rocket, "model", "models/weapons/w_models/w_rocket.mdl");
				DispatchKeyValueVector(rocket, "origin", vecLook);
				DispatchKeyValueVector(rocket, "angles", vecAngles);
				DispatchSpawn(rocket);

				TeleportEntity(rocket, vecLook, vecAngles, NULL_VECTOR);
				SetEntityMoveType(rocket, MOVETYPE_NONE);

				SetEntProp(rocket, Prop_Data, "m_CollisionGroup", 13);
				SetEntPropEnt(rocket, Prop_Data, "m_hPhysicsAttacker", shooter);

				g_Detonators[shooter].Push(EntIndexToEntRef(rocket));

				EmitSoundToAll("weapons/grappling_hook_impact_default.wav", rocket);

				AttachParticle(rocket, "mvm_emergency_light_flash");
				AttachParticle(rocket, "cart_flashinglight_glow_red ");

				TE_SetupBeamPoints(vecOrigin, vecLook, g_iLaserMaterial, g_iHaloMaterial, 30, 30, 2.0, 0.5, 0.5, 5, 1.0, view_as<int>({245, 245, 245, 225}), 5);
				TE_SendToAll();
			}
		}
	}
}

public void OnGameFrame()
{
	int entity = -1; int shooter = -1; int target = 0;
	float vecOrigin[3]; float vecVelocity[3]; float fSpeed; float vecAngles[3]; float vecTarget[3]; float vecAim[3];

	while ((entity = FindEntityByClassname(entity, "tf_projectile_rocket")) != -1)
	{
		shooter = -1;
		if ((shooter = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity")) == -1)
		{
			continue;
		}

		if (g_bIsHomingRocket[entity])
		{
			target = GetClosestTarget(entity, shooter);

			if (target == 0)
			{
				continue;
			}

			GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vecOrigin);

			GetClientAbsOrigin(target, vecTarget);

			vecTarget[2] += 40.0;

			MakeVectorFromPoints(vecOrigin, vecTarget , vecAim);

			GetEntPropVector(entity, Prop_Data, "m_vecAbsVelocity", vecVelocity);

			fSpeed = GetVectorLength(vecVelocity);

			AddVectors(vecVelocity, vecAim, vecVelocity);

			NormalizeVector(vecVelocity, vecVelocity);

			GetEntPropVector(entity, Prop_Data, "m_angRotation", vecAngles);

			GetVectorAngles(vecVelocity, vecAngles);

			SetEntPropVector(entity, Prop_Data, "m_angRotation", vecAngles);

			ScaleVector(vecVelocity, fSpeed);

			SetEntPropVector(entity, Prop_Data, "m_vecAbsVelocity", vecVelocity);
		}
	}
}

public Action Timer_SpawnRocket(Handle timer, any data)
{
	int shooter = data;

	if (!IsPlayerAlive(shooter))
	{
		return Plugin_Continue;
	}

	int slot = GetActiveWeaponSlot(shooter);

	if (slot == -1)
	{
		return Plugin_Continue;
	}

	float vecOrigin[3];
	GetClientEyePosition(shooter, vecOrigin);

	float vecAngles[3];
	GetClientEyeAngles(shooter, vecAngles);

	VectorAddRotatedOffset(vecAngles, vecOrigin, view_as<float>({50.0, 0.0, 0.0}));

	vecAngles[0] += GetRandomFloat(-15.0, 15.0);
	vecAngles[1] += GetRandomFloat(-15.0, 15.0);
	vecAngles[2] += GetRandomFloat(-15.0, 15.0);

	int rocket = -1;
	if ((rocket = TF2_FireProjectile(vecOrigin, vecAngles, "tf_projectile_rocket", shooter, GetClientTeam(shooter), 2000.0, 90.0, view_as<bool>(GetRandomInt(0, 1)), GetEntPropEnt(shooter, Prop_Send, "m_hActiveWeapon"))) > 0)
	{
		//Stops rockets from destroying each other since they're spawning near each other.
		SDKHook(rocket, SDKHook_ShouldCollide, OnRocketCollide);

		g_bIsHomingRocket[rocket] = g_bAttribute_HomingRockets[shooter][slot];
		g_bIsSpawnedRocket[rocket] = true;
	}

	return Plugin_Continue;
}

public bool OnRocketCollide(int entity, int collisiongroup, int contentsmask, bool results)
{
	return false;
}

int TF2_FireProjectile(float vPos[3], float vAng[3], const char[] classname = "tf_projectile_rocket", int iOwner = 0, int iTeam = 0, float flSpeed = 1100.0, float flDamage = 90.0, bool bCrit = false, int iWeapon = -1)
{
	int iRocket = CreateEntityByName(classname);

	if (IsValidEntity(iRocket))
	{
		float vVel[3];
		GetAngleVectors(vAng, vVel, NULL_VECTOR, NULL_VECTOR);

		ScaleVector(vVel, flSpeed);

		DispatchSpawn(iRocket);
		TeleportEntity(iRocket, vPos, vAng, vVel);

		SDKCall(g_hSDKSetRocketDamage, iRocket, flDamage);

		SetEntProp(iRocket, Prop_Send, "m_CollisionGroup", 0);
		SetEntProp(iRocket, Prop_Data, "m_takedamage", 0);
		SetEntProp(iRocket, Prop_Send, "m_bCritical", bCrit);
		SetEntProp(iRocket, Prop_Send, "m_nSkin", (iTeam - 2));
		SetEntProp(iRocket, Prop_Send, "m_iTeamNum", iTeam);
		SetEntPropVector(iRocket, Prop_Send, "m_vecMins", view_as<float>({0.0,0.0,0.0}));
		SetEntPropVector(iRocket, Prop_Send, "m_vecMaxs", view_as<float>({0.0,0.0,0.0}));

		SetVariantInt(iTeam);
		AcceptEntityInput(iRocket, "TeamNum", -1, -1, 0);

		SetVariantInt(iTeam);
		AcceptEntityInput(iRocket, "SetTeam", -1, -1, 0);

		if (iOwner > 0)
		{
			SetEntPropEnt(iRocket, Prop_Send, "m_hOwnerEntity", iOwner);
		}

		if (iWeapon != -1)
		{
			SetEntPropEnt(iRocket, Prop_Send, "m_hOriginalLauncher", iWeapon); // GetEntPropEnt(baseRocket, Prop_Send, "m_hOriginalLauncher")
			SetEntPropEnt(iRocket, Prop_Send, "m_hLauncher", iWeapon); // GetEntPropEnt(baseRocket, Prop_Send, "m_hLauncher")
		}
	}

	return iRocket;
}

int GetClosestTarget(int entity, int owner)
{
	float distance;
	int target;

	float vecOrigin[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vecOrigin);

	float vecTarget[3]; float distance_check;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i) || !IsClientInGame(i) || !IsPlayerAlive(i) || i == owner || GetClientTeam(i) == GetClientTeam(owner))
		{
			continue;
		}

		GetClientAbsOrigin(i, vecTarget);

		distance_check = GetVectorDistance(vecOrigin, vecTarget);

		if (distance > 0.0)
		{
			if (distance_check < distance)
			{
				target = i;
				distance = distance_check;
			}
		}
		else
		{
			target = i;
			distance = distance_check;
		}
	}

	return target;
}

public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] weaponname, bool &result)
{
	int slot = GetActiveWeaponSlot(client);

	if (slot == -1)
	{
		return Plugin_Continue;
	}

	float time = GetGameTime();

	if (g_bAttribute_FireChairs[client][slot] && g_fFireChairDelay[client] <= time)
	{
		float vecOrigin[3];
		GetClientEyePosition(client, vecOrigin);

		float vecAngles[3];
		GetClientEyeAngles(client, vecAngles);

		VectorAddRotatedOffset(vecAngles, vecOrigin, view_as<float>({50.0, 0.0, -50.0}));

		float vecVelocity[3];
		AnglesToVelocity(vecAngles, 500000.0, vecVelocity);

		int chair = CreateEntityByName("prop_physics_override");

		if (IsValidEntity(chair))
		{
			//DispatchKeyValue(chair, "model", "models/props_manor/chair_01.mdl");
			DispatchKeyValue(chair, "model", "models/props_spytech/terminal_chair.mdl");
			DispatchKeyValue(chair, "disableshadows", "1");
			DispatchKeyValueVector(chair, "origin", vecOrigin);
			DispatchKeyValueVector(chair, "angles", vecAngles);
			DispatchKeyValueVector(chair, "basevelocity", vecVelocity);
			DispatchKeyValueVector(chair, "velocity", vecVelocity);
			DispatchSpawn(chair);

			TeleportEntity(chair, vecOrigin, vecAngles, vecVelocity);

			SetEntProp(chair, Prop_Data, "m_CollisionGroup", 13);
			SetEntPropEnt(chair, Prop_Data, "m_hPhysicsAttacker", client);
			SDKHook(chair, SDKHook_VPhysicsUpdatePost, OnChairPhysicsUpdate);

			AutoKillEnt(chair, 10.0);

			g_fFireChairDelay[client] = time + 0.1;
		}
	}

	if (g_bAttribute_LaunchBackwardsFast[client][slot])
	{
		float vecAngles[3];
		GetClientEyeAngles(client, vecAngles);

		float vecVelocity[3];
		AnglesToVelocity(vecAngles, 50000.0, vecVelocity);

		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vecVelocity);
	}

	return Plugin_Continue;
}

public void OnChairPhysicsUpdate(int chair)
{
	int owner = GetEntPropEnt(chair, Prop_Data, "m_hPhysicsAttacker");

	if (owner < 1)
	{
		return;
	}

	float vecOrigin1[3]; float vecOrigin2[3];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || i == owner)
		{
			continue;
		}

		GetClientAbsOrigin(i, vecOrigin1);
		GetEntPropVector(chair, Prop_Data, "m_vecAbsOrigin", vecOrigin2);

		if (GetVectorDistance(vecOrigin1, vecOrigin2) <= 80.0)
		{
			SDKHooks_TakeDamage(i, 0, owner, 99999.0, DMG_CLUB, 0);
		}
	}
}

int GetWeaponSlot(int client, int weapon) {
	if (client == 0 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client) || weapon == 0 || weapon < MaxClients || !IsValidEntity(weapon)) {
		return -1;
	}

	for (int i = 0; i < 5; i++) {
		if (GetPlayerWeaponSlot(client, i) != weapon) {
			continue;
		}

		return i;
	}

	return -1;
}

void CreateExplosion(float pos[3]) {
	int entity = CreateEntityByName("env_explosion");
	if (!IsValidEntity(entity)) {
		return;
	}

	DispatchKeyValue(entity, "fireballsprite", "sprites/zerogxplode.spr");
	DispatchKeyValue(entity, "iMagnitude", "0");
	DispatchKeyValue(entity, "iRadiusOverride", "0");
	DispatchKeyValue(entity, "rendermode", "5");
	DispatchKeyValue(entity, "spawnflags", "1");

	DispatchSpawn(entity);
	TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(entity, "Explode");
}

void TF2_Particle(char[] name, float origin[3], int entity = -1, float angles[3] = {0.0, 0.0, 0.0}, bool resetparticles = false) {
	int tblidx = FindStringTable("ParticleEffectNames");

	char tmp[256];
	int stridx = INVALID_STRING_INDEX;

	for (int i = 0; i < GetStringTableNumStrings(tblidx); i++) {
		ReadStringTable(tblidx, i, tmp, sizeof(tmp));
		if (StrEqual(tmp, name, false)) {
			stridx = i;
			break;
		}
	}

	TE_Start("TFParticleEffect");
	TE_WriteFloat("m_vecOrigin[0]", origin[0]);
	TE_WriteFloat("m_vecOrigin[1]", origin[1]);
	TE_WriteFloat("m_vecOrigin[2]", origin[2]);
	TE_WriteVector("m_vecAngles", angles);
	TE_WriteNum("m_iParticleSystemIndex", stridx);
	TE_WriteNum("entindex", entity);
	TE_WriteNum("m_iAttachType", 5);
	TE_WriteNum("m_bResetParticles", resetparticles);
	TE_SendToAll();
}

int GetActiveWeaponSlot(int client) {
	if (client == 0 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client)) {
		return -1;
	}
	
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	
	if (weapon == 0 || weapon < MaxClients || !IsValidEntity(weapon)) {
		return -1;
	}
	
	for (int i = 0; i < 5; i++) {
		if (GetPlayerWeaponSlot(client, i) != weapon) {
			continue;
		}

		return i;
	}

	return -1;
}

bool TF2_RemoveRagdoll(int client) {
	int ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");

	if (IsValidEdict(ragdoll)) {
		char classname[64];
		GetEdictClassname(ragdoll, classname, sizeof(classname));

		if (StrEqual(classname, "tf_ragdoll", false)) {
			RemoveEdict(ragdoll);
		}
		
		return true;
	}
	
	return false;
}

int TF2_SpawnRagdoll(int client, float destruct = 10.0, int flags = 0, float vel[3] = NULL_VECTOR) {
	int ragdoll = CreateEntityByName("tf_ragdoll");

	if (IsValidEntity(ragdoll)) {
		float vecOrigin[3];
		GetClientAbsOrigin(client, vecOrigin);

		float vecAngles[3];
		GetClientAbsAngles(client, vecAngles);

		TeleportEntity(ragdoll, vecOrigin, vecAngles, NULL_VECTOR);

		SetEntProp(ragdoll, Prop_Send, "m_iPlayerIndex", client);
		SetEntProp(ragdoll, Prop_Send, "m_iTeam", GetClientTeam(client));
		SetEntProp(ragdoll, Prop_Send, "m_iClass", view_as<int>(TF2_GetPlayerClass(client)));
		SetEntProp(ragdoll, Prop_Send, "m_nForceBone", 1);
		SetEntProp(ragdoll, Prop_Send, "m_iDamageCustom", TF_CUSTOM_TAUNT_ENGINEER_SMASH);
		
		SetEntProp(ragdoll, Prop_Send, "m_bGib", (flags & RAG_GIBBED) == RAG_GIBBED);
		SetEntProp(ragdoll, Prop_Send, "m_bBurning", (flags & RAG_BURNING) == RAG_BURNING);
		SetEntProp(ragdoll, Prop_Send, "m_bElectrocuted", (flags & RAG_ELECTROCUTED) == RAG_ELECTROCUTED);
		SetEntProp(ragdoll, Prop_Send, "m_bFeignDeath", (flags & RAG_FEIGNDEATH) == RAG_FEIGNDEATH);
		SetEntProp(ragdoll, Prop_Send, "m_bWasDisguised", (flags & RAG_WASDISGUISED) == RAG_WASDISGUISED);
		SetEntProp(ragdoll, Prop_Send, "m_bBecomeAsh", (flags & RAG_BECOMEASH) == RAG_BECOMEASH);
		SetEntProp(ragdoll, Prop_Send, "m_bOnGround", (flags & RAG_ONGROUND) == RAG_ONGROUND);
		SetEntProp(ragdoll, Prop_Send, "m_bCloaked", (flags & RAG_CLOAKED) == RAG_CLOAKED);
		SetEntProp(ragdoll, Prop_Send, "m_bGoldRagdoll", (flags & RAG_GOLDEN) == RAG_GOLDEN);
		SetEntProp(ragdoll, Prop_Send, "m_bIceRagdoll", (flags & RAG_ICE) == RAG_ICE);
		SetEntProp(ragdoll, Prop_Send, "m_bCritOnHardHit", (flags & RAG_CRITONHARDCRIT) == RAG_CRITONHARDCRIT);
		
		SetEntPropVector(ragdoll, Prop_Send, "m_vecRagdollOrigin", vecOrigin);
		SetEntPropVector(ragdoll, Prop_Send, "m_vecRagdollVelocity", vel);
		SetEntPropVector(ragdoll, Prop_Send, "m_vecForce", vel);
		
		if ((flags & RAG_HIGHVELOCITY) == RAG_HIGHVELOCITY) {
			//from Rowedahelicon
			float HighVel[3];
			HighVel[0] = -180000.552734;
			HighVel[1] = -1800.552734;
			HighVel[2] = 800000.552734; //Muhahahahaha
			
			SetEntPropVector(ragdoll, Prop_Send, "m_vecRagdollVelocity", HighVel);
			SetEntPropVector(ragdoll, Prop_Send, "m_vecForce", HighVel);
		}
		
		//Makes sure the ragdoll isn't malformed on spawn.
		SetEntPropFloat(ragdoll, Prop_Send, "m_flHeadScale", (flags & RAG_NOHEAD) == RAG_NOHEAD ? 0.0 : 1.0);
		SetEntPropFloat(ragdoll, Prop_Send, "m_flTorsoScale", 1.0);
		SetEntPropFloat(ragdoll, Prop_Send, "m_flHandScale", 1.0);
		
		DispatchSpawn(ragdoll);
		ActivateEntity(ragdoll);
		
		SetEntPropEnt(client, Prop_Send, "m_hRagdoll", ragdoll, 0);
		
		if (destruct > 0.0) {
			char output[64];
			Format(output, sizeof(output), "OnUser1 !self:kill::%.1f:1", destruct);

			SetVariantString(output);
			AcceptEntityInput(ragdoll, "AddOutput");
			AcceptEntityInput(ragdoll, "FireUser1");
		}
	}

	return ragdoll;
}

void SpeakResponseConceptDelayed(int client, const char[] concept, float delayed = 0.0, const char[] context = "", const char[] class = "") {
	if (delayed < 0.0) {
		delayed = 0.0;
	}
	
	DataPack hPack;
	CreateDataTimer(delayed, __Timer_DelayClientConcept, hPack, TIMER_FLAG_NO_MAPCHANGE);
	hPack.WriteCell(GetClientUserId(client));
	hPack.WriteString(concept);
	hPack.WriteString(context);
	hPack.WriteString(class);
}

public Action __Timer_DelayClientConcept(Handle timer, DataPack data) {
	data.Reset();
	int client = GetClientOfUserId(data.ReadCell());

	char sConcept[256];
	data.ReadString(sConcept, sizeof(sConcept));

	char sContext[64];
	data.ReadString(sContext, sizeof(sContext));

	char sClass[64];
	data.ReadString(sClass, sizeof(sClass));

	if (client > 0 && IsClientInGame(client) && IsPlayerAlive(client)) {
		SpeakResponseConcept(client, sConcept, sContext, sClass);
	}

	return Plugin_Stop;
}

void SpeakResponseConcept(int client, const char[] concept, const char[] context = "", const char[] class = "") {
	bool hascontext;

	//For class specific context basically.
	if (strlen(context) > 0) {
		SetVariantString(context);
		AcceptEntityInput(client, "AddContext");

		hascontext = true;
	}

	//dominations require you add more context to them for certain things.
	if (strlen(class) > 0) {
		char sClass[64];
		FormatEx(sClass, sizeof(sClass), "victimclass:%s", class);
		SetVariantString(sClass);
		AcceptEntityInput(client, "AddContext");

		hascontext = true;
	}

	SetVariantString(concept);
	AcceptEntityInput(client, "SpeakResponseConcept");

	if (hascontext) {
		AcceptEntityInput(client, "ClearContext");
	}
}

void TF2_AddPlayerHealth(int client, int amount, float overheal = 1.5, bool additive = false, bool fireevent = true, int healer = -1) {
	int maxhealth = GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, client);
	int actualmax = ((maxhealth == -1 || maxhealth == 80896) ? GetEntProp(client, Prop_Data, "m_iMaxHealth") : maxhealth);
	
	int iHealth = GetClientHealth(client);
	int iNewHealth = iHealth + amount;
	int iMax = additive ? (actualmax + RoundFloat(overheal)) : RoundFloat(float(actualmax) * overheal);

	if (iHealth < iMax) {
		if (iNewHealth < 1) {
			iNewHealth = 1;
		} else if (iNewHealth > iMax) {
			iNewHealth = iMax;
		}

		if (fireevent) {
			int value = iNewHealth - iHealth;
			int userid = GetClientUserId(client);

			Event event = CreateEvent("player_healed", true);
			event.SetBool("sourcemod", true);
			event.SetInt("patient", userid);
			event.SetInt("healer", healer > 0 && IsClientInGame(healer) ? GetClientUserId(healer) : userid);
			event.SetInt("amount", value);
			event.Fire();

			event = CreateEvent("player_healonhit", true);
			event.SetBool("sourcemod", true);
			event.SetInt("amount", value);
			event.SetInt("entindex", client);
			event.Fire();
		}

		SetEntityHealth(client, iNewHealth);
	}
}

int CreateParticle(const char[] name, float origin[3], float time = 0.0, float angles[3] = {0.0, 0.0, 0.0}, float offsets[3] = {0.0, 0.0, 0.0}) {
	if (strlen(name) == 0) {
		return -1;
	}

	origin[0] += offsets[0];
	origin[1] += offsets[1];
	origin[2] += offsets[2];

	int entity = CreateEntityByName("info_particle_system");

	if (IsValidEntity(entity)) {
		DispatchKeyValueVector(entity, "origin", origin);
		DispatchKeyValueVector(entity, "angles", angles);
		DispatchKeyValue(entity, "effect_name", name);

		DispatchSpawn(entity);
		ActivateEntity(entity);
		AcceptEntityInput(entity, "Start");

		if (time > 0.0) {
			char output[64];
			Format(output, sizeof(output), "OnUser1 !self:kill::%.1f:1", time);
			SetVariantString(output);
			AcceptEntityInput(entity, "AddOutput");
			AcceptEntityInput(entity, "FireUser1");
		}
	}

	return entity;
}

void VectorAddRotatedOffset(const float angle[3], float buffer[3], const float offset[3]) {
    float vecForward[3]; float vecLeft[3]; float vecUp[3];
    GetAngleVectors(angle, vecForward, vecLeft, vecUp);

    ScaleVector(vecForward, offset[0]);
    ScaleVector(vecLeft, offset[1]);
    ScaleVector(vecUp, offset[2]);

    float vecAdd[3];
    AddVectors(vecAdd, vecForward, vecAdd);
    AddVectors(vecAdd, vecLeft, vecAdd);
    AddVectors(vecAdd, vecUp, vecAdd);

    AddVectors(buffer, vecAdd, buffer);
}

bool GetClientLookOrigin(int client, float pOrigin[3], bool filter_players = true, float distance = 35.0) {
	if (client == 0 || client > MaxClients || !IsClientInGame(client)) {
		return false;
	}

	float vOrigin[3];
	GetClientEyePosition(client,vOrigin);

	float vAngles[3];
	GetClientEyeAngles(client, vAngles);

	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, filter_players ? TraceEntityFilterPlayer : TraceEntityFilterNone, client);
	bool bReturn = TR_DidHit(trace);

	if (bReturn) {
		float vStart[3];
		TR_GetEndPosition(vStart, trace);

		float vBuffer[3];
		GetAngleVectors(vAngles, vBuffer, NULL_VECTOR, NULL_VECTOR);

		pOrigin[0] = vStart[0] + (vBuffer[0] * -distance);
		pOrigin[1] = vStart[1] + (vBuffer[1] * -distance);
		pOrigin[2] = vStart[2] + (vBuffer[2] * -distance);
	}

	delete trace;
	return bReturn;
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask, any data) {
	return entity > MaxClients || !entity;
}

public bool TraceEntityFilterNone(int entity, int contentsMask, any data) {
	return entity != data;
}

int AttachParticle(int entity, const char[] name, float time = 0.0, const char[] attach = "", float angles[3] = {0.0, 0.0, 0.0}, float offsets[3] = {0.0, 0.0, 0.0}) {
	float origin[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
	
	origin[0] += offsets[0];
	origin[1] += offsets[1];
	origin[2] += offsets[2];

	int particle = CreateEntityByName("info_particle_system");

	if (IsValidEntity(particle)) {
		DispatchKeyValueVector(particle, "origin", origin);
		DispatchKeyValueVector(particle, "angles", angles);
		DispatchKeyValue(particle, "effect_name", name);

		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "Start");

		if (time > 0.0) {
			char output[64];
			Format(output, sizeof(output), "OnUser1 !self:kill::%.1f:1", time);
			SetVariantString(output);
			AcceptEntityInput(particle, "AddOutput");
			AcceptEntityInput(particle, "FireUser1");
		}
		
		SetVariantString("!activator");
		AcceptEntityInput(particle, "SetParent", entity, particle, 0);

		if (strlen(attach) > 0) {
			SetVariantString(attach);
			AcceptEntityInput(particle, "SetParentAttachmentMaintainOffset", particle, particle, 0);
		}
	}

	return particle;
}

void AnglesToVelocity(const float pAngles[3], float pScale, float pResults[3]) {
	GetAngleVectors(pAngles, pResults, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(pResults, pScale);
}

void AutoKillEnt(int entity, float duration) {
	char output[64];
	Format(output, sizeof(output), "OnUser1 !self:kill::%.1f:1", duration);
	SetVariantString(output);
	AcceptEntityInput(entity, "AddOutput");
	AcceptEntityInput(entity, "FireUser1");
}