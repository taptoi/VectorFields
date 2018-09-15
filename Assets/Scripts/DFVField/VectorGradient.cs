using System.Collections;
using System.Collections.Generic;
using System;
using UnityEngine;

public static class VectorGradient {


    public static SerializableVector3[,,] CalculateGradients(float[,,] m)
    {
        int resZ = m.GetLength(0);
        int resY = m.GetLength(1);
        int resX = m.GetLength(2);
        SerializableVector3[,,] gs = new SerializableVector3[resZ, resY, resX];
        for (int k = 0; k < resZ; k++)
        {
            for (int j = 0; j < resY; j++)
            {
                for (int i = 0; i < resX; i++)
                {
                    Func<float> gi = () =>
                    {
                        if (i == 0)
                            return SingleBorderI0(m, j, k);
                        else if (i == resX - 1)
                            return SingleBorderIN(m, j, k);
                        else
                            return SingleInnerI(m, i, j, k);
                    };
                    Func<float> gj = () =>
                    {
                        if (j == 0)
                            return SingleBorderJ0(m, i, k);
                        else if (j == resY - 1)
                            return SingleBorderJN(m, i, k);
                        else
                            return SingleInnerJ(m, i, j, k);
                    };
                    Func<float> gk = () =>
                    {
                        if (k == 0)
                            return SingleBorderK0(m, i, j);
                        else if (k == resZ - 1)
                            return SingleBorderKN(m, i, j);
                        else
                            return SingleInnerK(m, i, j, k);
                    };
                    gs[k, j, i] = new SerializableVector3(gi(), gj(), gk());
                }
            }
        }
        return gs;
    }

    static float SingleInnerI(float[,,] m, int i, int j, int k)
    {
        return 0.5f * (m[k, j, i + 1] - m[k, j, i - 1]);
    }

    static float SingleInnerJ(float[,,] m, int i, int j, int k)
    {
        return 0.5f * (m[k, j + 1, i] - m[k, j - 1, i]);
    }

    static float SingleInnerK(float[,,] m, int i, int j, int k)
    {
        return 0.5f * (m[k + 1, j, i] - m[k - 1, j, i]);
    }

    static float SingleBorderI0(float[,,] m, int j, int k)
    {
        return m[k, j, 1] - m[k, j, 0];
    }

    static float SingleBorderJ0(float[,,] m, int i, int k)
    {
        return m[k, 1, i] - m[k, 0, i];
    }

    static float SingleBorderK0(float[,,] m, int i, int j)
    {
        return m[1, j, i] - m[0, j, i];
    }

    static float SingleBorderIN(float[,,] m, int j, int k)
    {
        var N = m.GetLength(2);
        return m[k, j, N - 1] - m[k, j, N - 2];
    }

    static float SingleBorderJN(float[,,] m, int i, int k)
    {
        var N = m.GetLength(1);
        return m[k, N - 1, i] - m[k, N - 2, i];
    }

    static float SingleBorderKN(float[,,] m, int i, int j)
    {
        var N = m.GetLength(0);
        return m[N - 1, j, i] - m[N - 2, j, i];
    }

}
