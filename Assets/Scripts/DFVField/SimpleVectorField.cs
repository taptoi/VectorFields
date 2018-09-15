using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.Linq;

public class SimpleVectorField : MonoBehaviour {

    public struct ShaderParticle
    {
        public Vector3 pos;
        public Vector3 vel;
    }

    ParticleSystem.Particle[] ps;
    public float gainX = -0.005f;
    public float gainY = -0.005f;
    public float gainZ = -0.005f;
    public float A = 1f;
    public float f = 0.5f;
    public ComputeShader shader;
    ComputeBuffer particleBuffer;
    ShaderParticle[] shaderParticles;

	// Use this for initialization
	void Start () {
        var psys = this.GetComponentInParent<ParticleSystem>();
        psys.Stop();
        ps = new ParticleSystem.Particle[psys.main.maxParticles];
        psys.Emit(psys.main.maxParticles);
        psys.GetParticles(ps);
        for (int i = 0; i < ps.Length; i++)
        {
            ps[i].position = Random.insideUnitSphere * 5;
        }
        psys.SetParticles(ps, ps.Length);
        particleBuffer = new ComputeBuffer(psys.main.maxParticles, 
                                           sizeof(float) * 6, 
                                           ComputeBufferType.Default);
	}
	
	// Update is called once per frame
	void Update () {
        var psys = this.GetComponentInParent<ParticleSystem>();
        if (psys.particleCount % 1024 != 0)
            Debug.LogError("Particle count must be divisible by 1024.");
        int particleCount = psys.GetParticles(ps);
        if (ps == null || particleCount == 0) return;
        var kernelHandle = shader.FindKernel("CSMain");
        // Update positions on shader particles
        shaderParticles = ps.Select(p => new ShaderParticle { pos = p.position, vel = p.totalVelocity }).ToArray();
        shader.SetFloat("particleCount", particleCount);
        particleBuffer.SetData(shaderParticles);
        shader.SetBuffer(kernelHandle, "ParticleBuffer", particleBuffer);

        // Update params
        shader.SetFloat("gainX", gainX);
        shader.SetFloat("gainY", gainY);
        shader.SetFloat("gainZ", gainZ);
        shader.SetFloat("A", A);
        shader.SetFloat("f", f);
        shader.SetFloat("time", Time.time);
        // Perform computation of velocities on GPU
        shader.Dispatch(kernelHandle, particleCount / 64, 1, 1);
        // Get data from buffer
        shaderParticles = new ShaderParticle[particleCount];
        particleBuffer.GetData(shaderParticles);

        // Update data
        for (int i = 0; i < particleCount; i++)
        {
            ps[i].velocity = shaderParticles[i].vel;
        }
        psys.SetParticles(ps, particleCount);
	}

    private void OnDestroy()
    {
        particleBuffer.Release();
    }

}
