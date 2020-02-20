Shader "Unlit/MyCelsheder"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_ShadowTint("Shadow Tint", Color) = (1,1,1,1)
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
				half4 color:COLOR;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
				float3 worldNormal : NORMAL;// направление нормали
				half4 color : COLOR;
				float3 viewDir : TEXCOORD1; //модель Blinn-Phong, нам надо знать направление взгляда. Unity предоставляет нам эту информацию
			};
			
			sampler2D _MainTex;
			float4 _MainTex_ST;
			float _ShadowTint;
			

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.worldNormal = UnityObjectToWorldNormal(v.normal);// преобразование нормали поверхности из локальных координат в мировые:
				o.color = v.color;
				o.viewDir = WorldSpaceViewDir(v.vertex);//модель Blinn-Phong, нам надо знать направление взгляда. Unity предоставляет нам эту информацию
				return o;
			}
			static const half4 SPECULAR_COLOR = half4(1, 1, 1, 1); // отражение бликов

			//Исправляем затенение на внутренней стороне если свет падает с внешней стороны, внутренняя сторона тоже будет освещена. Давайте исправим это, используя строенную переменную VFACE.
			fixed4 frag (v2f i, half facing : VFACE) : SV_Target //используем сложную маску shadow mask
			{
				// нормализируем вектор нормали
				float3 normal = normalize(i.worldNormal);
				// Разворачиваем нормаль внутрь, если 
				// нормаль направлена от камеры
				half sign = facing > 0.5 ? 1.0 : -1.0;
				normal *= sign;
				// Считаем Dot Product для нормали и направления к источнику света
				// _WorldSpaceLightPos0 - встроенная переменная Unity
				float NdotL = dot(_WorldSpaceLightPos0, normal);
				// Пересчитываем NdotL, чтобы он был в диапазоне от 0 до 1,
				// чтобы сравнивать его со значением красного канала
				float NdotL01 = NdotL * 0.5 + 0.5;
				// Т.к. пороговое значение для затенения теперь может быть разным
				// для разных пикселей, мы рассчитываем маску,
				// по которой будем затенять пиксели.
				// Используем step функцию и красный канал в качестве порогового значения.
				// "1 - step" инвертирует маску. По умолчанию у нас 1 в освещенной зоне,
				// а 0 в затенённой. Нам же надо иметь 1 в затенённой зоне (маска).
				half shadowMask = 1 - step(1 - i.color.r, NdotL01);
				// Рассчитываем блик
				float3 viewDir=normalize(i.viewDir);
				// Считаем half vector
				float3 halfVector = normalize(_WorldSpaceLightPos0 + viewDir);
				// Ограничиваем значение NdotH между 0 и 1
				float NdotH = saturate(dot(halfVector, normal));
				// Рассчитываем фиксированный размер блика
				//если зелёный канал = 0, блик полностью отсутствует;
				//значение от 0 до 1 контролирует размер блика.
				float specularIntensity = i.color.g == 0 ? 0 : pow(NdotH, i.color.g * 500);
				// Создаём маску блика
				half specularMask = step(0.5, specularIntensity);
				// Умножаем маску блика на инвертированную маску тени,
				// чтобы блик не появлялся в затенённой области
				specularMask *= (1 - shadowMask);
				// Получаем цвет с текстуры
				fixed4 texCol = tex2D(_MainTex, i.uv);
				// Применяем затенение по маске
				half4 shadowCol = texCol * shadowMask * _ShadowTint;
				
				// Смешивем цвет текстуры (освещенная часть) и цвет тени по маске
				half4 col = lerp(texCol, shadowCol, shadowMask);

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
				half4 color : COLOR; // Контролируем толщину контура с помощью Vertex Color
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
			};

			// Объявляем переменные
			half _OutlineWidth;
			static const half4 OUTLINE_COLOR = half4(0,0,0,0);

			v2f vert (appdata v) // делает одинаковую толщену контура
			{
				// Смещаем вершины по направлению нормали на заданное расстояние
				// Конвертируем положение и нормаль вертекса в clip space
				float4 clipPosition = UnityObjectToClipPos(v.vertex);
				float3 clipNormal = mul((float3x3) UNITY_MATRIX_VP, mul((float3x3) UNITY_MATRIX_M, v.normal));
				
				// Считаем смещение вершины по направлению нормали.
				// Также учитываем перспективное искажение и домножаем на компонент W,
				// чтобы сделать смещение постоянным,
				// вне зависимости от расстояния до камеры
				float2 offset = normalize(clipNormal.xy) * _OutlineWidth * clipPosition.w * v.color.b; //Контролируем толщину контура с помощью Vertex Color считаем offset.
				
				// Т.к. рассчет теперь ведется в пространстве экрана, 
				// надо учитывать соотношение сторон
				// и сделать толщину контура постоянной при любом aspect ratio.
				// _ScreenParams - встроенная переменная Unity
				float aspect = _ScreenParams.x / _ScreenParams.y;
				offset.y *= aspect;
				
				// Применяем смещение
				clipPosition.xy += offset;
				
				v2f o;
				o.vertex = clipPosition;
				return o;
			}

			fixed4 frag () : SV_Target
			{
				// Все пиксели контура имеют один и тот же цвет
				return OUTLINE_COLOR;
			}
			ENDCG
		}
		//Отбрасываем тень
		UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
	}
}
