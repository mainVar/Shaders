using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class AsciiCamera : MonoBehaviour
{
    public Material material;
    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Graphics.Blit(source, destination, material);
    }
    private void Update()
    {
        material.SetFloat("Width", Screen.width);
        material.SetFloat("Height", Screen.height);
    }
}
