using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.Linq;
using System.IO;
using System;
//using System.Runtime.Serialization.Formatters.Binary; 

public class VectorField : MonoBehaviour
{

    public int posX;
    public int posY;
    public int posZ;
    public int scaleX = 1;
    public int scaleY = 1;
    public int scaleZ = 1;
    //public int resX = 100;
    //public int resY = 100;
    //public int resZ = 100;
    public float tailFactor = 0.5f;
    public float boundaryForceFactor = 0.005f;
    public float vNoiseFactor = 1;
    public float sNoiseFactor = 1;
    public float vNoiseTimeScale = 0.1f;
    public float sNoiseTimeScale = 0.1f;
    public float gradientFactor = 0.5f;
    public string imageStackFolderPath;
    public float alphaFactor = 0.1f;
    //public float redFactor = 0.1f;
    //public float greenFactor = 0.1f;
    //public float blueFactor = 0.1f;
    public float delta = 1.0f;
    public float seedShift = 555f;
    public float voronoiFreq = 0.1f;
    public float voronoiAmp = 5.0f;
    public float voronoiJitter = 1.1f;
    public int voronoiOctaves = 1;
    public float cameraSpeed = 0.5f;


    private float[,,] fieldMatrix;
    private Mesh fieldMesh;

    // struct
    struct Particle
    {
        public Vector3 position;
        public Vector3 velocity;
        public float life;
    }

    /// <summary>
    /// Size in octet of the Particle struct.
    /// since float = 4 bytes...
    /// 4 floats = 16 bytes
    /// </summary>
    //private const int SIZE_PARTICLE = 24;
    private const int SIZE_PARTICLE = 28; // since property "life" is added...
    private const int SIZE_GRADIENT = 12;
    /// <summary>
    /// Number of Particle created in the system.
    /// </summary>
    private int particleCount = 128000;

    /// <summary>
    /// Material used to draw the Particle on screen.
    /// </summary>
    public Material material;

    /// <summary>
    /// Compute shader used to update the Particles.
    /// </summary>
    public ComputeShader computeShader;

    /// <summary>
    /// Id of the kernel used.
    /// </summary>
    private int mComputeShaderKernelID;

    /// <summary>
    /// Buffer holding the Particles.
    /// </summary>
    ComputeBuffer particleBuffer;

    /// <summary>
    /// Buffer holding the gradient vectors.
    /// </summary>
    //ComputeBuffer gradientBuffer;

    /// <summary>
    /// Number of particle per warp.
    /// </summary>
    private const int WARP_SIZE = 256; // TODO?

    /// <summary>
    /// Number of warp needed.
    /// </summary>
    private int mWarpCount; // TODO?

    //private SerializableVector3[,,] grads;

    private Particle[] particleArray;

    private Texture2D[] textures;

    private const string dataFileName = "3DScanData.dat";

    private RenderTexture pastFrame;
    private Material tailShaderMaterial;
    private Light mainLight;


    // Use this for initialization
    void Start()
    {
        mainLight = FindObjectOfType<Light>();
        tailShaderMaterial = new Material(Shader.Find("Hidden/TailShader"));
        tailShaderMaterial.hideFlags = HideFlags.DontSave;
        pastFrame = new RenderTexture(Screen.width, Screen.height, 16);
        InitComputeShader();

    }




    // Update is called once per frame
    void Update()
    {
        transform.RotateAround(new Vector3(scaleX / 2, scaleY / 2, scaleZ / 2), 
                               Vector3.up, 
                               cameraSpeed * Time.deltaTime);

        //float[] mousePosition2D = { cursorPos.x, cursorPos.y };

        // Send datas to the compute shader
        computeShader.SetFloat("deltaTime", Time.deltaTime);
        computeShader.SetFloat("time", Time.time);
        computeShader.SetFloat("boundaryForceFactor", boundaryForceFactor);
        computeShader.SetFloat("gradientFactor", gradientFactor);
        computeShader.SetFloat("vNoiseFactor", vNoiseFactor);
        computeShader.SetFloat("sNoiseFactor", sNoiseFactor);
        computeShader.SetFloat("vNoiseTimeScale", vNoiseTimeScale);
        computeShader.SetFloat("sNoiseTimeScale", sNoiseTimeScale);

        //computeShader.SetInt("resX", resX);
        //computeShader.SetInt("resY", resY);
        //computeShader.SetInt("resZ", resZ);
        computeShader.SetInt("scaleX", scaleX);
        computeShader.SetInt("scaleY", scaleY);
        computeShader.SetInt("scaleZ", scaleZ);
        computeShader.SetFloat("delta", delta);
        computeShader.SetFloat("seedShift", seedShift);
        computeShader.SetFloat("voronoiFreq", voronoiFreq);
        computeShader.SetFloat("voronoiAmp", voronoiAmp);
        computeShader.SetFloat("voronoiJitter", voronoiJitter);
        computeShader.SetInt("voronoiOctaves", voronoiOctaves);

        // Update the Particles
        computeShader.Dispatch(mComputeShaderKernelID, mWarpCount, 1, 1);
    }


    void InitComputeShader()
    {
        mWarpCount = Mathf.CeilToInt((float)particleCount / WARP_SIZE);

        // initialize the particles
        particleArray = new Particle[particleCount];

        for (int i = 0; i < particleCount; i++)
        {
            var q = Quaternion.Euler(UnityEngine.Random.value * 360,
                                     UnityEngine.Random.value * 360,
                                     UnityEngine.Random.value * 360);
            float r = UnityEngine.Random.value * scaleX / 50;
            //float x = UnityEngine.Random.value * scaleX;
            //float y = UnityEngine.Random.value * scaleY;
            //float z = UnityEngine.Random.value * scaleZ;
            Vector3 c = new Vector3(scaleX / 2, scaleY / 2, scaleZ / 2);
            Vector3 xyz = new Vector3(1, 1, 1);
            // Rotate and scale vector within a sphere and center
            xyz = q * xyz * r + c; 
            //xyz.Normalize();


            particleArray[i].position.x = xyz.x;
            particleArray[i].position.y = xyz.y;
            particleArray[i].position.z = xyz.z;

            particleArray[i].velocity.x = 0;
            particleArray[i].velocity.y = 0;
            particleArray[i].velocity.z = 0;

            // Initial life value
            particleArray[i].life = 50 + UnityEngine.Random.value * 50;
        }

        // create compute buffers
        particleBuffer = new ComputeBuffer(particleCount, SIZE_PARTICLE);
        //gradientBuffer = new ComputeBuffer(resZ * resY * resX, SIZE_GRADIENT);

        particleBuffer.SetData(particleArray);
        //gradientBuffer.SetData(grads.Cast<SerializableVector3>()
                               //.Select(sv => new Vector3(sv.x, sv.y, sv.z))
                               //.ToArray());

        // find the id of the kernel
        mComputeShaderKernelID = computeShader.FindKernel("DFVField");

        // bind the compute buffer to the shader and the compute shader
        computeShader.SetBuffer(mComputeShaderKernelID, "particleBuffer", particleBuffer);
        material.SetBuffer("particleBuffer", particleBuffer);

        //computeShader.SetBuffer(mComputeShaderKernelID, "gradientBuffer", gradientBuffer);
    }

    void OnRenderObject()
    {
        material.SetPass(0);
        material.SetFloat("_a", alphaFactor);
        //material.SetFloat("_r", redFactor);
        //material.SetFloat("_g", greenFactor);
        //material.SetFloat("_b", blueFactor);
        material.SetFloat("_lightRange", mainLight.range);
        material.SetFloat("_lightIntensity", mainLight.intensity);
        material.SetFloat("_lightX", mainLight.transform.position.x);
        material.SetFloat("_lightY", mainLight.transform.position.y);
        material.SetFloat("_lightZ", mainLight.transform.position.z);
        material.SetFloat("_lightR", mainLight.color.r);
        material.SetFloat("_lightG", mainLight.color.g);
        material.SetFloat("_lightB", mainLight.color.b);

        Graphics.DrawProcedural(MeshTopology.Points, 1, particleCount);
    }

    void OnRenderImage(RenderTexture src, RenderTexture dst)
    {
        // pass previous frame in to the shader
        tailShaderMaterial.SetTexture("_PrevFrame", pastFrame);
        // to allow people to use transparency we must accept other transparencies other than 1
        tailShaderMaterial.SetFloat("_MaxTransparency", tailFactor);
        // run the shader
        Graphics.Blit(src, dst, tailShaderMaterial);
        // backup the frame to re-use next iteration
        Graphics.Blit(RenderTexture.active, pastFrame);
    }

    void OnDestroy()
    {
        if (particleBuffer != null)
            particleBuffer.Release();
        //if (gradientBuffer != null)
            //gradientBuffer.Release();
        if (tailShaderMaterial != null)
            DestroyImmediate(tailShaderMaterial);
    }


    //void Start()
    //{
    //    tailShaderMaterial = new Material(Shader.Find("Hidden/TailShader"));
    //    tailShaderMaterial.hideFlags = HideFlags.DontSave;
    //    //var loadData = DeserializeSaved3DData();
    //    //if (false)//loadData.Length > 0)
    //    //    grads = loadData;
    //    //else
    //    //{
    //    pastFrame = new RenderTexture(Screen.width, Screen.height, 16);
    //    //textures = LoadImageStack(imageStackFolderPath);
    //    //if (textures.Length < resZ)
    //    //    throw new InvalidOperationException("Z resolution must not exceed no. images in the stack");
    //    // ordered [z][y][x], see https://eli.thegreenplace.net/2015/memory-layout-of-multi-dimensional-arrays
    //    //fieldMatrix = new float[resZ, resY, resX];
    //    //for (int k = 0; k < resZ; k++)
    //    //{
    //    //    for (int j = 0; j < resY; j++)
    //    //    {
    //    //        for (int i = 0; i < resX; i++)
    //    //        {
    //    //            fieldMatrix[k, j, i] = textures[k].GetPixel(i, j).grayscale;
    //    //            if (k == 0 || k == resZ)
    //    //                fieldMatrix[k, j, i] *= 0.8f;
    //    //        }
    //    //    }
    //    //}
    //    //grads = VectorGradient.CalculateGradients(fieldMatrix);
    //    //SerializeAndSave3DData();
    //    //}
    //    InitComputeShader();
    //    //DebugX();
    //    //DrawHelperMesh();
    //}


    //private Texture2D[] LoadImageStack(string folderPath)
    //{
    //    var path = Directory.GetCurrentDirectory() + folderPath;
    //    var files = Directory.GetFiles(path);
    //    return files.Where(fp => !fp.Contains(".meta"))
    //                .OrderBy(fp => fp)
    //                .Select(fp => LoadPNG(fp)).ToArray();
    //}

    //private static Texture2D LoadPNG(string filePath)
    //{
    //    Debug.Log(filePath);
    //    Texture2D tex = null;
    //    byte[] fileData;

    //    if (File.Exists(filePath))
    //    {
    //        fileData = File.ReadAllBytes(filePath);
    //        tex = new Texture2D(2, 2);
    //        tex.LoadImage(fileData); //..this will auto-resize the texture dimensions.
    //    }
    //    return tex;
    //}

    // For arrays ordered [z][y][x]
    // See https://stackoverflow.com/questions/21596373/compute-shaders-input-3d-array-of-floats
    // And https://eli.thegreenplace.net/2015/memory-layout-of-multi-dimensional-arrays
    //int DebugGetFlattenedIndex(int x, int y, int z, int lenX, int lenY, int lenZ)
    //{
    //    return z * (lenY * lenX) + y * (lenX) + x;
    //}

    //private void SerializeAndSave3DData()
    //{
    //    var path = Directory.GetCurrentDirectory() + "/" + dataFileName;
    //    BinarySerializeObject(path, grads);
    //}

    //private SerializableVector3[,,] DeserializeSaved3DData()
    //{
    //    var path = Directory.GetCurrentDirectory() + "/" + dataFileName;
    //    if (!File.Exists(path))
    //        return new SerializableVector3[0,0,0];
    //    return (SerializableVector3[,,])BinaryDeserializeObject(path);
    //}


    //public static void BinarySerializeObject(string path, object obj)
    //{
    //    using (StreamWriter streamWriter = new StreamWriter(path))
    //    {
    //        BinaryFormatter binaryFormatter = new BinaryFormatter();
    //        binaryFormatter.Serialize(streamWriter.BaseStream, obj);

    //    }
    //}

    //public static object BinaryDeserializeObject(string path)
    //{
    //    using (StreamReader streamReader = new StreamReader(path))
    //    {
    //        BinaryFormatter binaryFormatter = new BinaryFormatter();
    //        object obj;
    //        obj = binaryFormatter.Deserialize(streamReader.BaseStream);

    //        return obj;
    //    }
    //}

    //void DebugX()
    //{
    //    var gs = grads.Cast<Vector3>().ToArray();
    //    for (int i = 0; i < particleArray.Length; i++)
    //    {
    //        int ix = (int)(particleArray[i].position.x * resX / scaleX);
    //        int iy = (int)(particleArray[i].position.y * resY / scaleY);
    //        int iz = (int)(particleArray[i].position.z * resZ / scaleZ);
    //        int iv = DebugGetFlattenedIndex(ix, iy, iz, resX, resY, resZ);
    //       Vector3 g = gs[iv];
    //    }
    //}


}