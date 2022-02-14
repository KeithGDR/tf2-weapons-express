#pragma semicolon 1
//#pragma newdecls required

#include <sourcemod>
#include <sourcemod-misc>
#include <sdkhooks>
#include <tf2_stocks>

#include <cw3-attributes-redux>
#include <cw3-core-redux>
#include <tf2attributes>

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
	name = "[TF2] CW3-Attributes: Weapons Express",
	author = "Keith Warren (Shaders Allen)",
	description = "Custom weapon attributes by yours truly.",
	version = "1.0.0",
	url = "https://www.shadersallen.com/"
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

	if (!IsPlayerIndex(client))
	{
		return;
	}

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

		TF2_CreateExplosion(vecOrigin, 99999.0, 5000.0, 5000.0, client, secondary, GetClientTeam(client) == 2 ? 3 : 2);

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

		CreateTempParticle("fluidSmokeExpl_ring_mvm", vecOrigin, client);
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
}

public void Event_OnArrowImpact(Event event, const char[] name, bool dontBroadcast)
{
	int client = event.GetInt("shooter");

	if (!IsPlayerIndex(client))
	{
		return;
	}

	int slot = GetClientActiveSlot(client);

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

	if (IsPlayerIndex(client))
	{
		TF2_CreateRagdoll(client, 10.0, false, true);
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
		g_bAttribute_FireChairs[client][slot] = StringToBool(value);
		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "fire barrage of rockets"))
	{
		g_bAttribute_FireBarrage[client][slot] = StringToBool(value);
		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "homing rockets"))
	{
		g_bAttribute_HomingRockets[client][slot] = StringToBool(value);
		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "prelaunched rockets"))
	{
		g_bAttribute_PrelaunchedRockets[client][slot] = StringToBool(value);

		delete g_RocketOrigins[client];
		g_RocketOrigins[client] = new ArrayList(3);

		delete g_RocketAngles[client];
		g_RocketAngles[client] = new ArrayList(3);

		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "heal on pill explode"))
	{
		g_bAttribute_HealOnPillExplode[client][slot] = StringToBool(value);

		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "rocket detonator"))
	{
		g_bAttribute_RocketDetonator[client][slot] = StringToBool(value);

		delete g_Detonators[client];
		g_Detonators[client] = new ArrayList();

		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "launch backwards fast"))
	{
		g_bAttribute_LaunchBackwardsFast[client][slot] = StringToBool(value);

		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "explode on land with jetpack"))
	{
		g_bAttribute_ExplodeOnLandWithJetpack[client][slot] = StringToBool(value);

		action = Plugin_Handled;
	}
	else if (StrEqual(attrib, "freeze enemies near arrows"))
	{
		g_bAttribute_FreezeEnemiesNearArrow[client][slot] = StringToBool(value);

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

	int slot = GetClientActiveSlot(attacker);

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
	if (!IsPlayerIndex(client))
	{
		return Plugin_Continue;
	}

	int slot = GetClientActiveSlot(client);
	int active = GetActiveWeapon(client);

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

				TF2_FireProjectile(vecOrigin, vecAngles, "tf_projectile_rocket", client, GetClientTeam(client), 1100.0, 90.0, GetRandomBool(), active);
			}

			EmitSoundToClientSafe(client, "passtime/pass_to_me.wav");
			SpeakResponseConceptDelayed(client, "TLK_PLAYER_CHEERS", 0.3);

			g_RocketOrigins[client].Clear();
			g_RocketAngles[client].Clear();

			g_bIsFiringRockets[client] = false;
		}

		if (g_bAttribute_RocketDetonator[client][slot] && g_Detonators[client].Length > 0)
		{
			EmitSoundToClientSafe(client, "weapons/stickybomblauncher_det.wav");
			SpeakResponseConceptDelayed(client, "TLK_PLAYER_CHEERS", 0.6);

			CreateTimer(0.2, Timer_DetonateRockets, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action Timer_DetonateRockets(Handle timer, any data)
{
	int client = GetClientOfUserId(data);

	if (!IsPlayerIndex(client) || !IsClientConnected(client) || !IsClientInGame(client) || !IsPlayerAlive(client))
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
			TF2_CreateExplosion(vecOrigin, 99999.0, 2500.0, 1000.0, client, rocket, GetClientTeam(client) == 2 ? 3 : 2, "cinefx_goldrush", "items/cart_explode.wav", 200.0, 300.0, 3.0);

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

		if (IsPlayerIndex(owner))
		{
			int slot = GetClientActiveSlot(owner);
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

				CreateParticle(team == 2 ? "hell_megaheal_red_shower" : "hell_megaheal_blue_shower", 5.0, vecOrigin);
				EmitSoundToAllSafe("misc/halloween/spell_overheal.wav", entity);
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

	int slot = GetClientActiveSlot(shooter);

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
			EmitSoundToClientSafe(shooter, "ui/hitsound_menu_note8.wav", SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, (100 + (g_RocketOrigins[shooter].Length * 3)));
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
			GetClientLookPosition(shooter, vecLook, 0.0);

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

				EmitSoundToAllSafe("weapons/grappling_hook_impact_default.wav", rocket);

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

	int slot = GetClientActiveSlot(shooter);

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
	if ((rocket = TF2_FireProjectile(vecOrigin, vecAngles, "tf_projectile_rocket", shooter, GetClientTeam(shooter), 2000.0, 90.0, GetRandomBool(), GetActiveWeapon(shooter))) > 0)
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
	int slot = GetClientActiveSlot(client);

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

			SetEntitySelfDestruct(chair, 10.0);

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

	if (!IsPlayerIndex(owner))
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
