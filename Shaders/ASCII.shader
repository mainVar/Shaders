Shader "Unlit/ASCII"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        Width("Width", float) = 1024
        Height("Height", float) = 768
        CellWidth("CellWidth", float) = 10
        CellHeight("CellHeight", float) = 30
        AddTex("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            sampler2D AddTex;
            float4 _MainTex_ST;
            float Width;
            float Height;
            float CellWidth;
            float CellHeight;
            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
                //Берём номер пикселя. Функция ceil - берёт целую часть от результата
                float pixelX = ceil(i.uv.x * Width);
                float pixelY = ceil(i.uv.y * Height);
                //Берём оффсеты для рассчёта центрального пикселя блока
                float halfCellX = ceil(CellWidth / 2);
                float halfCellY = ceil(CellHeight / 2);
                //Возвращаем координату центрального элемента каждой ячейки
                float xColorPos = (ceil(pixelX / CellWidth) * CellWidth + halfCellX) / Width;
                float yColorPos = (ceil(pixelY / CellHeight) * CellHeight + halfCellY) / Height;
                fixed4 resultCol = tex2D(_MainTex, float2(xColorPos, yColorPos));

                //Cчитаем индекс пикселя внутри ячейки
                float pixelXIndex = (i.uv.x * Width) % CellWidth;
                float pixelYIndex = (i.uv.y * Height) % CellHeight;
                //Рассчитываем оффсеты для взятия символа из второй текстуры. Если их не брать - то замещение будет только на первый символ из таблицы
                float sum = resultCol.r + resultCol.g + resultCol.b;
                float xOffset = ceil(sum / 0.1) * 0.1;
                float yOffset = ceil(sum / 0.333) * 0.333;
                //Берём координату первого символа из таблицы и добавляем к ней оффсет
                float2 percentPosition = i.uv;
                percentPosition.x = pixelXIndex / CellWidth / 10 + xOffset;
                percentPosition.y = pixelYIndex / CellHeight / 3 + yOffset;
                //Возвращаем конкретный пиксель по указанным координатам уже со второй текстуры
                return tex2D(AddTex, percentPosition);
            }
            ENDCG
        }
    }
}
