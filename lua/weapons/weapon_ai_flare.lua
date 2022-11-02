AddCSLuaFile()

SWEP.PrintName				= "Flare"
SWEP.Category 				= 'Alien: Isolation'

SWEP.Author					= "Wheatley"
SWEP.Purpose				= ""

SWEP.Spawnable				= true
SWEP.UseHands				= true
SWEP.DrawAmmo				= true

SWEP.ViewModel				= "models/weapons/c_ai_flare.mdl"
SWEP.WorldModel				= "models/weapons/w_flare.mdl"

SWEP.ViewModelFOV			= 75
SWEP.Slot					= 1
SWEP.SlotPos				= 5

SWEP.Primary.ClipSize		= 1
SWEP.Primary.DefaultClip	= 1
SWEP.Primary.Automatic		= true
SWEP.Primary.Ammo			= "ai_flares"


SWEP.Secondary.Ammo         = "None"
SWEP.Secondary.ClipSize     = -1
SWEP.Secondary.DefaultClip  = 0
SWEP.Secondary.Automatic	= false

SWEP.ThrowingTime			= 0
SWEP.Throwing				= false
SWEP.NextThrow				= 0
SWEP.ThrowingForce			= 400
SWEP.HoldedFlareLifeTime	= 0
SWEP.LastOn					= 0
SWEP.LastFoleySound			= 0

if CLIENT then
	game.AddParticles( 'particles/alien_isolation.pcf' )
end
-- alien_flare_fire
if SERVER then
	resource.AddSingleFile( 'models/weapons/c_ai_flare.mdl' )
	util.AddNetworkString( 'FLARE_LIGHT' )
else
	language.Add( 'ai_flares_ammo', 'Flare' )
	net.Receive( 'FLARE_LIGHT', function()
		local ent = net.ReadEntity()
		local dlight = DynamicLight( ent:EntIndex() )
		if ( dlight and IsValid( ent ) ) then
			dlight.pos = ent:GetPos()
			dlight.r = 255
			dlight.g = 5
			dlight.b = 0
			dlight.brightness = 2
			dlight.Decay = 2000
			dlight.Size = 800
			dlight.DieTime = CurTime() + 0.6
		end
	end )
end

game.AddAmmoType( {
	name = 'ai_flares', 
} )

function SWEP:Initialize()
	self:SetHoldType( 'slam' )
end

function SWEP:Think()
	if self.IsOn and SERVER then
		net.Start( 'FLARE_LIGHT' )
			net.WriteEntity( self )
		net.Send( player.GetAll() )
		self:SetNWBool( 'Throwing', self.Throwing )
		self:SetNWInt( 'LastOn', self.LastOn )
	end
	
	if self.HoldedFlareLifeTime < CurTime() and self.IsOn and SERVER then
		self.IsOn = false
		self:SetNWBool( 'IsON', false )
		self:EmitSound( 'weapons/flare_out.wav' )
		if self:GetOwner().FireLoopSound then self:GetOwner().FireLoopSound:Stop() end
		self:SendWeaponAnim( ACT_VM_HOLSTER )
		timer.Simple( 1, function() if IsValid( self ) then if self:GetOwner():GetAmmoCount( 'ai_flares' ) <= 0 then return end self:SendWeaponAnim( ACT_VM_DRAW ) end end )
	end
	
	if CLIENT and self:GetNWBool( 'IsON' ) then
		local prec = math.Clamp( self:GetNWInt( 'LastOn' ) - CurTime(), 0, 1 )
		local tprec = ( self:GetNWBool( 'Throwing' ) ) and 1 or 0
		local ang = self:GetOwner():EyeAngles()
		ang = Angle( ang.p, ang.y, ang.r - 45 )
		ParticleEffect( 'alien_flare_fire', 
		self:GetOwner():GetShootPos() + self:GetOwner():EyeAngles():Forward() * ( 20 - 23 * tprec ) + ( self:GetOwner():EyeAngles():Right() * ( 7 - ( 6 * prec ) ) ) + self:GetOwner():EyeAngles():Up() * ( 1.3 - ( 7 * prec ) ), 
		ang, self )
	end
	
	if SERVER and self:GetNWBool( 'IsON' ) then
		local prec = math.Clamp( self.LastOn - CurTime(), 0, 1 )
		local tprec = ( self.ThrowingTime > CurTime() ) and 1 or 0
		local ang = self:GetOwner():EyeAngles()
		ang = Angle( ang.p, ang.y, ang.r - 45 )
		ParticleEffect( 'alien_flare_fire', 
		self:GetOwner():GetShootPos() - self:GetOwner():EyeAngles():Forward() * 10 + self:GetOwner():EyeAngles():Right() * 22 + self:GetOwner():EyeAngles():Up() * 1.3, 
		ang, self )
	end
	
	if self.Throwing then if self.LastFoleySound == 0 then self.LastFoleySound = 1 self:EmitSound( 'weapons/flare_throw_foley.wav' ) end self.ThrowingForce = math.Clamp( self.ThrowingForce + 5, 400, 1000 ) end
	
	if self.ThrowingTime < CurTime() and self.Throwing and self.NextThrow < CurTime() then
		if self.LastFoleySound == 1 then self.LastFoleySound = 0 self:EmitSound( 'weapons/flare_throwing_foley.wav' ) end
		self:SetNextPrimaryFire( CurTime() + 1 )
		self:SetNextSecondaryFire( CurTime() + 1 )
		self:SendWeaponAnim( ACT_VM_THROW )
		self.Throwing = false
		self:GetOwner():ViewPunch( Angle( 0, 10 + 10 * ( self.ThrowingForce / 1000 ), -10 - 10 * ( self.ThrowingForce / 1000 ) ) )
		timer.Simple( 0.2, function() if IsValid( self ) then
			if CLIENT then return end
			if self:GetOwner().FireLoopSound then self:GetOwner().FireLoopSound:Stop() end
				self.IsOn = false
				self:SetNWBool( 'IsON', false )
				local flare = ents.Create( 'prop_physics' )
				flare:SetPos( self:GetOwner():GetShootPos() + self:GetOwner():EyeAngles():Right() * 5 )
				flare:SetAngles( self:GetOwner():EyeAngles() - Angle( 0, 0, 15 ) )
				flare:SetModel( 'models/weapons/w_flare_nocap.mdl' )
				flare:Spawn()
				flare:Activate()
				flare:GetPhysicsObject():SetVelocity( self:GetOwner():GetAimVector() * self.ThrowingForce )
				flare:GetPhysicsObject():AddAngleVelocity( -Vector( 60, 0, 0 ) )
				flare.FireLoopSound = CreateSound( flare, 'weapons/flare_loop.wav' )
				flare.FireLoopSound:Play()
				flare.Life = self.HoldedFlareLifeTime
				hook.Add( 'Think', 'ThinkOnFlare_' .. flare:EntIndex(), function()
					if !IsValid( flare ) then return end
					if !flare.Life or flare.Life < CurTime() then if flare.FireLoopSound then flare.FireLoopSound:Stop() end flare:EmitSound( 'weapons/flare_out.wav' ) flare:Remove() return end
					net.Start( 'FLARE_LIGHT' )
						net.WriteEntity( flare )
					net.Send( player.GetAll() )
					ParticleEffect( 'alien_flare_fire', flare:GetPos(), flare:GetAngles(), self )
				end )
				self.ThrowingForce = 400
				self:SetNextPrimaryFire( CurTime() + 1.3 )
				self:SetNextSecondaryFire( CurTime() + 1.3 )
				timer.Simple( 0.3, function() 
					if IsValid( self ) then 
						if self:GetOwner():GetAmmoCount( 'ai_flares' ) <= 0 then 
							self:Remove() 
						end 
					self:SendWeaponAnim( ACT_VM_DRAW ) 
					end 
				end )
			end 
		end )
		self:SetHoldType( 'slam' )
		self:GetOwner():SetAnimation( PLAYER_ATTACK1 )
	end
	
	if self.ThrowingTime > CurTime() and self.Throwing and self:GetOwner():KeyDown( IN_ATTACK ) then
		self.LastFoleySound = 0
		self.Throwing = false
		self:SendWeaponAnim( ACT_VM_LOWERED_TO_IDLE )
		self.NextThrow = CurTime() + 1
		return
	end
	
	if self.ThrowingTime > CurTime() and !self.Throwing and self.NextThrow < CurTime() then
		self.Throwing = true
		self:SendWeaponAnim( ACT_VM_IDLE_TO_LOWERED )
	end
end

function SWEP:PrimaryAttack()
	if !self:CanPrimaryAttack() then return end
	if self.Throwing then self.Throwing = false end
	if self:GetNWBool( 'IsON' ) then return false end
	timer.Simple( 0.8, function() if IsValid( self ) then self:SetNWBool( 'IsON', true ) self:SetHoldType( 'grenade' ) self:TakePrimaryAmmo( 1 ) self.IsOn = true end end )
	self.HoldedFlareLifeTime = CurTime() + 22
	self:SendWeaponAnim( ACT_VM_PRIMARYATTACK )
	self.NextThrow = CurTime() + 1
	self.LastOn = CurTime() + 1.5
	timer.Simple( 0.2, function() self:EmitSound( 'weapons/flare_ignite.wav' ) end )
	self:GetOwner().FireLoopSound = CreateSound( self, 'weapons/flare_loop.wav' )
	timer.Simple( 1.5, function() if self:GetOwner().FireLoopSound then self:GetOwner().FireLoopSound:Play() end end )
	self:SetNextPrimaryFire( CurTime() + 1 )
end

function SWEP:Holster()
	if self:GetNWBool( 'IsON' ) and SERVER then
		local flare = ents.Create( 'prop_physics' )
		flare:SetPos( self:GetOwner():GetShootPos() + self:GetOwner():EyeAngles():Forward() * 5 )
		flare:SetModel( 'models/weapons/w_flare_nocap.mdl' )
		flare:Spawn()
		flare:Activate()
		if self:GetOwner().FireLoopSound then self:GetOwner().FireLoopSound:Stop() end
		flare.FireLoopSound = CreateSound( flare, 'weapons/flare_loop.wav' )
		flare.FireLoopSound:Play()
		flare.Life = self.HoldedFlareLifeTime
		hook.Add( 'Think', 'ThinkOnFlare_' .. flare:EntIndex(), function()
			if !IsValid( flare ) then return end
			if !flare.Life or flare.Life < CurTime() then if flare.FireLoopSound then flare.FireLoopSound:Stop() end flare:EmitSound( 'weapons/flare_out.wav' ) flare:Remove() return end
			net.Start( 'FLARE_LIGHT' )
				net.WriteEntity( flare )
			net.Send( player.GetAll() )
			ParticleEffect( 'alien_flare_fire', flare:GetPos(), flare:GetAngles(), self )
		end )
	end
	self.IsOn = false
	self:SetNWBool( 'IsON', false )
	return true
end

function SWEP:SecondaryAttack()
	if self.NextThrow > CurTime() or !self:GetNWBool( 'IsON' ) then return end
	self.ThrowingTime = CurTime() + 0.1
end