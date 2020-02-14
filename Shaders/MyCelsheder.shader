Shader "Unlit/MyCelsheder"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_ShadowStrength ("Shadow Strength", Range(0, 1)) = 0.5
		_OutlineWidth ("Outline Width", Range(0, 0.1)) = 0.01
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
			Tags// освещение с одной стороны от одного Directional Light
			{
				"LightMode"="ForwardBase"
				"PassFlags"="OnlyDirectional"
			}

			Cull Off  // Backface culling
			Stencil //принудительно переписали значение Stencil на 1.
            {
                Ref 1 //сравнивает значение пикселя со значением Ref, в данном случае с 1.
                Comp Always //проверка всегда проходится с положительным результатом, при этом не важно, значение больше, меньше или равно.
                Pass Replace //если проверка прошла успешно, то значение Stencil для данного пикселя заменяется значением Ref.
            }
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
           
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
				float3 normal : NORMAL;// направление нормали 
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
				float3 worldNormal : NORMAL;// направление нормали 
            };
			
            sampler2D _MainTex;
            float4 _MainTex_ST;
			float _ShadowStrength;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.worldNormal = UnityObjectToWorldNormal(v.normal);// преобразование нормали поверхности из локальных координат в мировые:
               
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // нормализируем вектор нормали
			   float3 normal = normalize(i.worldNormal);
			   // Считаем Dot Product для нормали и направления к источнику света
			   // _WorldSpaceLightPos0 - встроенная переменная Unity
			   float NdotL = dot(_WorldSpaceLightPos0, normal);
			   // Считаем интенсивность света на поверхности
			   // Если поверхность повернута к источнику света (NdotL>0), то она освещена полностью
			   // В другом случае Shadow Strength для затенения
			   float lightIntensity = NdotL > 0 ? 1 : _ShadowStrength;
			   // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
                // apply fog
               col *= lightIntensity;
               return col;
            }
            ENDCG
        }

		Pass
		{	
			// Скрываем полигоны, повернутые к камере
			//Cull Front // плигоны что отвёрнуты от камеры
			Cull Off //формировании силуэта принимали участие все полигоны, а не только те, которые отвернуты от камеры
			 Stencil
            {
                Ref 1
                Comp Greater
            }
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
			};

			// Объявляем переменные
			half _OutlineWidth;
			static const half4 OUTLINE_COLOR = half4(0,0,0,0);

			v2f vert (appdata v)
			{
				// Смещаем вершины по направлению нормали на заданное расстояние
				v.vertex.xyz += v.normal * _OutlineWidth;
				
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				
				return o;
			}

			fixed4 frag () : SV_Target
			{
				// Все пиксели контура имеют один и тот же цвет
				return OUTLINE_COLOR;
			}
		ENDCG
	}
	 UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
	}
}
