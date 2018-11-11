// Made By: Jakub P. Szarkowicz
// Email: Jakubshark@gmail.com

Shader "Custom/Szark Water" 
{
	Properties 
	{
		[Header(Low Poly)]
		_LowPoly ("Low Poly Effect", Range(0, 1)) = 0

		[Header(Texture)]
		_MainTex ("Main Texture", 2D) = "white" {}

		[Header(Normals)]
		_Smoothness ("Smoothness", Range(0, 1)) = 0
		_NormalStrength ("Normal Strength", Range(0, 1)) = 1
		_FlowSpeed ("Flow Speed", Range(0, 1)) = 0.1
		[Toggle]
		_WorldSpaceNrm ("World Space", Float) = 0
		_NormalScale ("Normal Scale", Float) = 1
		[Space] [Normal]
		_Normal ("Normal Map", 2D) = "bump" {}
		_FlowMap ("Flow Map", 2D) = "white" {}

		[Header(Falloff)]
		_ShallowColor ("Shallow Color", Color) = (0.65,0.9,1,1)
		_DeepColor ("Deep Color", Color) = (0.13,0.57,0.73,1)
		[Space]
		_FalloffStrength ("Falloff Strength", Range(0, 1)) = 0.25
		_FalloffDepth ("Falloff Depth", Range(0, 1)) = 0.5

		[Header(Foam)]
		[Toggle]
		_UseRamp ("Use Ramp", Float) = 0
		_FoamRamp ("Foam Ramp", 2D) = "white" {}
		_FoamAmount ("Foam Amount", Range(0, 1)) = 0.1
		_FoamColor ("Foam Color", Color) = (1,1,1,1)

		[Header(Distortion)]
		_RefractionStrength ("Refraction Strength", Range(0, 1)) = 0.30
		_TexDistortion ("Texture Distortion", Range(0, 1)) = 0.25

		[Header(Waves)]
		_WaveNoise ("Wave Noise", 2D) = "white" {}
		_WaveDir ("Wave Direction", Vector) = (0, 0, 0.1, 1)
		_WaveLerp ("Noise / Uniform Lerp", Range(0, 1)) = 1
		_WaveAmp ("Wave Amplitude", Range(0, 20)) = 0.5
		_WaveSpeed ("Wave Speed", Range(0, 10)) = 0.5

		[Header(Height Coloring)]
		_HeightSoftness ("Height Softness", Range(0, 1)) = 1
		_HeightBrightness ("Height Brightness", Range(0, 1)) = 0.25
		_HeightSpread ("Height Spread", Range(0, 1)) = 0.5
	}
	SubShader 
	{
		Tags 
		{ 
			"RenderType"="Transparent" 
			"Queue"="Transparent" 
			"ForceNoShadowCasting" = "True" 
			"IgnoreProjector"="True"
		}

		GrabPass { "_Refraction" }
		Cull off

		CGPROGRAM

		#pragma surface surf Standard fullforwardshadows vertex:vert
		#pragma target 4.0

		struct Input 
		{
			float4 grabUV;
			float4 screenPos;

			float3 wNormal;
			float3 worldPos;

			float2 uv_MainTex;
			float2 uv_FlowMap;
			float2 uv_WaveNoise;
			float2 uv_Normal;

			float height;
		};

		sampler2D _MainTex;
		sampler2D _WaveNoise;
		sampler2D _Refraction;
		sampler2D _CameraDepthTexture;
		sampler2D _FoamRamp;
		sampler2D _FlowMap;
		sampler2D _Normal;

		fixed4 _FoamColor;
		fixed4 _ShallowColor;
		fixed4 _DeepColor;
		fixed4 _WaveDir;

		float _FalloffStrength;
		float _RefractionStrength;
		float _NormalStrength;

		float _WorldSpaceNrm;
		float _NormalScale;

		float _FoamAmount;
		float _TexDistortion;
		float _FalloffDepth;

		float _UseRamp;
		float _Smoothness;
		float _WaveSpeed;

		float _FlowSpeed;
		float _WaveAmp;
		float _WaveLerp;
		float _LowPoly;

		float _HeightSoftness;
		float _HeightBrightness;
		float _HeightSpread;

		void vert(inout appdata_full v, out Input o)
		{
			UNITY_INITIALIZE_OUTPUT(Input, o);
			float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
			float4 pos = UnityObjectToClipPos(v.vertex);

			o.wNormal = v.normal;
			o.worldPos = worldPos;

			float waveForm = sin((worldPos.x * _WaveDir.x) + (worldPos.y * _WaveDir.y) + 
				(worldPos.z * _WaveDir.z) + (_Time.y * _WaveSpeed)) * (0.25 * _WaveAmp);

			float4 noiseTex = tex2Dlod(_WaveNoise, float4(v.texcoord.xy, 0, 0));
			float noise = sin(_Time.y * _WaveSpeed * noiseTex) * _WaveAmp;

			v.vertex.y += lerp(noise, waveForm, _WaveLerp);
			o.height = v.vertex.y;

			o.screenPos = ComputeScreenPos(pos);
			o.grabUV = ComputeGrabScreenPos(pos - float4(0, waveForm * 2, 0, 0));
			COMPUTE_EYEDEPTH(o.screenPos.z);
		}

		half3 animateNormalMaps(Input IN)
		{
			// Flow Map
			float3 flowMap = tex2D(_FlowMap, IN.uv_FlowMap) * 2.0f - 1.0f;
			flowMap *= _FlowSpeed;

			float phase0 = frac(_Time.y * 0.5f + 0.5f);
			float phase1 = frac(_Time.y * 0.5f + 1.0f);

			float2 uv = _WorldSpaceNrm == 0 ? IN.uv_Normal : IN.worldPos.xz;
			uv *= 0.9 * _NormalScale;

			// Normals
			half3 tex1 = tex2D(_Normal, uv + flowMap.xy * phase0);
			half3 tex2 = tex2D(_Normal, uv + flowMap.xy * phase1);

			// Animated Flow
			float flowLerp = abs((0.5f - phase0) / 0.5f);
			return lerp(tex1, tex2, flowLerp);
		}

		float clamp(float val, float mi, float ma)
		{
			return val < mi ? mi : val > ma ? ma : val;
		}

		void surf (Input IN, inout SurfaceOutputStandard o) 
		{
			// Texture Distortion
			IN.uv_MainTex.x += (sin((IN.uv_MainTex.x + IN.uv_MainTex.y) * 
				8 + _Time.g * 1.3) * 0.02) * _TexDistortion;
			IN.uv_MainTex.y += (cos((IN.uv_MainTex.x - IN.uv_MainTex.y) * 
				8 + _Time.g * 2.7) * 0.02) * _TexDistortion;

			// Get Textures
			half3 normal = animateNormalMaps(IN);
			IN.grabUV.y += normal.y * _RefractionStrength;
			fixed4 refrTex = tex2Dproj(_Refraction, IN.grabUV) * _ShallowColor;
			fixed4 mainTex = tex2D (_MainTex, IN.uv_MainTex) * _DeepColor;

			// Get Depth for Refraction
			float depthSample = SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, IN.grabUV);
			float depth = LinearEyeDepth(depthSample).r;

			// Get Depth for Foam
			float foamSample = SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, IN.screenPos);
			float foamDepth = abs(LinearEyeDepth(foamSample).r - IN.screenPos.w);

			// Foam and Falloff
			float foam = _UseRamp == 0 ? 1-step(_FoamAmount, foamDepth) : 
				1 - saturate((1 - _FoamAmount) * foamDepth);
			float falloff = 1 - saturate((1 - _FalloffDepth) * (depth - IN.screenPos.w));
			float4 tex = lerp(mainTex, refrTex, falloff * _FalloffStrength);

			tex = lerp(tex, tex * _HeightBrightness * 2, clamp((IN.height + _HeightSpread * 0.5) * 
				(1 - _HeightSoftness) * 100, 0, 1));

			// Ramped Foam
			fixed4 foamTex = tex2D (_FoamRamp, float2(foam, 1));
			float4 foamRamp = _UseRamp == 1 ? foamTex : float4(0, 0, 0, 0);

			normal = IN.wNormal.y <= 0.5 ? float3(0.5, 0.5, 1) : normal;
			normal = lerp(normal, float3(0.5, 0.5, 1),  1 - _NormalStrength * 0.5);
			tex += _FoamColor * (_UseRamp == 1 ? foamRamp : foam);

			float lpEffect = dot(_WorldSpaceLightPos0.xyz, 
				normalize(cross(ddy(IN.worldPos), ddx(IN.worldPos))));
			lpEffect = lerp(1, lpEffect, _LowPoly);

			o.Albedo = tex * lpEffect;
			o.Normal = UnpackNormal(float4(normal, 1));
			o.Smoothness = _Smoothness;
		}

		ENDCG
	}
	FallBack "Diffuse"
}
