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
		_WorldSpaceNrm ("World Space", Range(0, 1)) = 0
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
		_FoamRampLerp ("Foam Ramp Lerp", Range(0, 1)) = 0
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

		float _FoamRampLerp;
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

		half3 animateNormalMap(Input IN)
		{
			float3 flowMap = (tex2D(_FlowMap, 
				IN.uv_FlowMap) * 2.0 - 1.0) * _FlowSpeed;

			float phase0 = frac(_Time.y * 0.5 + 0.5);
			float phase1 = frac(_Time.y * 0.5 + 1.0);

			float2 uv = lerp(IN.uv_Normal, IN.worldPos.xz, 
				_WorldSpaceNrm) * 0.9 * _NormalScale;

			half3 tex1 = tex2D(_Normal, uv + flowMap.xy * phase0);
			half3 tex2 = tex2D(_Normal, uv + flowMap.xy * phase1);

			return lerp(tex1, tex2, abs((0.5 - phase0) / 0.5));
		}

		float2 distortUV(float2 uv)
		{
			uv.x = (sin((uv.x + uv.y) * 8 + _Time.g * 1.3) * 0.02);
			uv.y = (cos((uv.x - uv.y) * 8 + _Time.g * 2.7) * 0.02);
			return uv;
		}

		float sampleDepth(float4 tex)
		{
			float depthSample = SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, tex);
			return LinearEyeDepth(depthSample).r;
		}

		void surf (Input IN, inout SurfaceOutputStandard o) 
		{
			// Textures
			fixed4 refrTex = tex2Dproj(_Refraction, IN.grabUV) * _ShallowColor;
			fixed4 mainTex = tex2D (_MainTex, IN.uv_MainTex) * _DeepColor;

			// Texture Distortion
			IN.uv_MainTex += distortUV(IN.uv_MainTex);

			// Normal
			half3 flatNormal = float3(0.5, 0.5, 1);
			half3 normal = IN.wNormal.y <= 0.5 ? flatNormal : animateNormalMap(IN);
			normal = lerp(normal, flatNormal,  1 - _NormalStrength * 0.5);

			// Refraction
			IN.grabUV.y += normal.y * _RefractionStrength;

			// Get Depth Samples
			float grabPassDepth = sampleDepth(IN.grabUV) - IN.screenPos.w;
			float screenDepth = abs(sampleDepth(IN.screenPos) - IN.screenPos.w);

			// Falloff
			float falloff = 1 - saturate((1 - _FalloffDepth) * grabPassDepth);
			float4 tex = lerp(mainTex, refrTex, falloff * _FalloffStrength);

			// Height Coloring
			float heightSpread = clamp((IN.height + _HeightSpread * 0.5), 0, 1);
			heightSpread *= (1 - _HeightSoftness) * 100;
			tex = lerp(tex, tex * _HeightBrightness * 2, heightSpread);

			// Foam
			float lineFoam = 1 - step(_FoamAmount, screenDepth);
			float rampFoam = 1 - saturate((1 - _FoamAmount) * 5 * grabPassDepth);

			// Foam Ramp
			fixed4 foamRamp = tex2D(_FoamRamp, float2(rampFoam, 1));
			tex += _FoamColor * lerp(lineFoam, foamRamp.r * rampFoam, _FoamRampLerp);

			// Low Poly Effect
			float derivative = normalize(cross(ddy(IN.worldPos), ddx(IN.worldPos)));
			tex += dot(_WorldSpaceLightPos0.xyz, derivative) * _LowPoly;

			o.Albedo = tex;
			o.Normal = UnpackNormal(float4(normal, 1));
			o.Smoothness = _Smoothness;
		}

		ENDCG
	}

	FallBack "Diffuse"
}
