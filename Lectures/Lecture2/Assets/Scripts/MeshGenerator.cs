using System;
using System.Collections.Generic;
using System.Linq;
using Unity.Mathematics;
using UnityEngine;
using F = System.Func<UnityEngine.Vector3, float>;

[RequireComponent(typeof(MeshFilter))]
public class MeshGenerator : MonoBehaviour
{
    private MeshFilter _filter;
    private Mesh _mesh;

    private class MarchingCubes
    {
        private readonly F _f;
        private readonly float _c;
        private readonly Resolution _x;
        private readonly Resolution _y;
        private readonly Resolution _z;

        private readonly List<Vector3> _vertices;
        private readonly List<Vector3> _normals;
        private readonly List<int> _indices;

        private static readonly int[] _bitCubeIndices = new int[] { 0, 4, 3, 7, 1, 5, 2, 6 };
        private static readonly Dictionary<int, (int, int)> _edgeToNeighbours = new Dictionary<int, (int, int)>()
        {
            [0] = (0, 4),
            [1] = (4, 6),
            [2] = (2, 6),
            [3] = (0, 2),
            [4] = (1, 5),
            [5] = (5, 7),
            [6] = (3, 7),
            [7] = (1, 3),
            [8] = (0, 1),
            [9] = (4, 5),
            [10] = (6, 7),
            [11] = (2, 3),
        };
        
        public MarchingCubes(F f, float c, Resolution x, Resolution y, Resolution z)
        {
            _f = f;
            _c = c;
            _x = x;
            _y = y;
            _z = z;

            (_vertices, _normals, _indices) = Generate();
        }

        public IEnumerable<Vector3> Vertices() => _vertices;

        public IEnumerable<int> Indices() => _indices;

        public IEnumerable<Vector3> Normals() => _normals;

        public class Resolution
        {
            private int _n;
            private float _lower;
            private float _upper;

            public Resolution(int n, double lower, double upper)
            {
                _n = n;
                _lower = (float) lower;
                _upper = (float) upper;
            }

            public int n => _n;

            public float At(int i)
            {
                var d = _upper - _lower;
                var k = (float) i / _n;
                return _lower + k * d;
            }
        }
   
        private byte Mask(int3 cubeIdx)
        {
            byte mask = 0;
            for (var i = 0; i < 8; i++)
            {
                if (ValueAt(cubeIdx, i) < _c)
                {
                    mask |= Convert.ToByte(1 << _bitCubeIndices[i]);
                }
            }

            return mask;
        }

        private static (int3, int3) Neighbours(int3 c, int e)
        {
            var (u, v) = _edgeToNeighbours[e];
            var pU = c + Offset(u);
            var pV = c + Offset(v);

            return string.CompareOrdinal(pU.ToString(), pV.ToString()) < 0 ? (pU, pV) : (pV, pU);
        }

        private static int3 Offset(int v) => new int3(v & 1, (v & 2) >> 1, (v & 4) >> 2);

        private float ValueAt(int3 idx, int v) => _f(LocationAt(idx, v));

        private float3 LocationAt(int3 idx, int v)
        {
            idx += Offset(v);
            return new float3(_x.At(idx.x), _y.At(idx.y), _z.At(idx.z));
        }

        private (List<Vector3>, List<Vector3>, List<int>) Generate()
        {
            var vertices = new List<Vector3>();
            var normals = new List<Vector3>();
            var edgeToOffset = new Dictionary<(int3, int3), int>();
            var indices = new List<int>();

            var cubes = from i in Enumerable.Range(0, _x.n)
                from j in Enumerable.Range(0, _y.n)
                from k in Enumerable.Range(0, _z.n)
                select new int3(i, j, k);

            foreach (var c in cubes)
            {
                var mask = Mask(c);
                var triangles = global::MarchingCubes.Tables.CaseToVertices[mask].Where(tr => tr.x >= 0);

                foreach (var tr in triangles)
                {
                    for (var i = 0; i < 3; i++)
                    {
                        var (u, v) = _edgeToNeighbours[tr[i]];
                        var e = Neighbours(c, tr[i]);
                        if (edgeToOffset.ContainsKey(e))
                        {
                            indices.Add(edgeToOffset[e]);
                            continue;
                        }

                        var z = InterpolateVertex(c, u, v);
                        var n = InterpolateNormal(z);
                        var vIdx = vertices.Count;
                        edgeToOffset[e] = vIdx;
                        vertices.Add(z);
                        normals.Add(n);
                        indices.Add(vIdx);
                    }
                }
            }

            return (vertices, normals, indices);
        }

        private Vector3 InterpolateNormal(Vector3 z)
        {
            const float eps = (float) 1e-3;
            var n = new Vector3(0, 0, 0);
            for (var i = 0; i < 3; i++)
            {
                var o = new Vector3(0, 0, 0) {[i] = eps};
                var f1 = _f(z + o);
                var f2 = _f(z - o);

                n[i] = f2 - f1;
            }

            return Vector3.Normalize(n);
        }

        private Vector3 InterpolateVertex(int3 c, int u, int v)
        {
            var fU = ValueAt(c, u);
            var fV = ValueAt(c, v);
            var lU = LocationAt(c, u);
            var lV = LocationAt(c, v);

            var k = Math.Abs(fU - _c) / Math.Abs(fU - fV);

            return Vector3.Lerp(lU, lV, k);
        }
    }

    private static Mesh Generate()
    {
        var r = new MarchingCubes.Resolution(50, -2, 2);
        var mc = new MarchingCubes(a =>
            {
                var c1 = a - new Vector3((float) 0.5, 0, 0);
                var s1 = 1 / Vector3.Dot(c1, c1);
                var c2 = a + new Vector3((float) 0.5, 0, 0);
                var s2 = 1 / (2 * Vector3.Dot(c2, c2));
                var c3 = a + new Vector3(0, (float) 0.8, 0);
                var s3 = 1 / (2 * Vector3.Dot(c3, c3));
                var c4 = a + - new Vector3(0, (float) 0.4, (float) 0.6);;
                var s4 = 1 / (3 * Vector3.Dot(c4, c4));
                return s1 + s2 + s3 + s4;
            },
            (float) 4,
            r,
            r,
            r);


        var m = new Mesh();

        m.SetVertices(mc.Vertices().ToList());
        m.SetNormals(mc.Normals().ToList());
        m.SetIndices(mc.Indices().ToArray(), MeshTopology.Triangles, 0);

        return m;
    }

    /// <summary>
    /// Executed by Unity upon object initialization. <see cref="https://docs.unity3d.com/Manual/ExecutionOrder.html"/>
    /// </summary>
    private void Awake()
    {
        _filter = GetComponent<MeshFilter>();
        // _mesh = _filter.mesh = new Mesh();
        _mesh = _filter.mesh = Generate();
        _mesh.MarkDynamic();
    }

    /// <summary>
    /// Executed by Unity on every first frame <see cref="https://docs.unity3d.com/Manual/ExecutionOrder.html"/>
    /// </summary>
    private void UpdateOld()
    {
        List<Vector3> sourceVertices = new List<Vector3>
        {
            new Vector3(0, 0, 0), // 0
            new Vector3(0, 1, 0), // 1
            new Vector3(1, 1, 0), // 2
            new Vector3(1, 0, 0), // 3
            new Vector3(0, 0, 1), // 4
            new Vector3(0, 1, 1), // 5
            new Vector3(1, 1, 1), // 6
            new Vector3(1, 0, 1), // 7
        };

        //a.k.a. indices
        int[] sourceTriangles =
        {
            0, 1, 2, 2, 3, 0, // front
            3, 2, 6, 6, 7, 3, // right
            7, 6, 5, 5, 4, 7, // back
            0, 4, 5, 5, 1, 0, // left
            0, 3, 7, 7, 4, 0, // bottom
            1, 5, 6, 6, 2, 1, // top
        };

        List<Vector3> vertices = new List<Vector3>();
        List<int> triangles = new List<int>();

        // What is going to happen if we don't split the vertices? Check it out by yourself by passing
        // sourceVertices and sourceTriangles to the mesh.
        for (int i = 0; i < sourceTriangles.Length; i++)
        {
            triangles.Add(vertices.Count);
            Vector3 vertexPos = sourceVertices[sourceTriangles[i]];
            
            //Uncomment for some animation:
            //vertexPos += new Vector3
            //(
            //    Mathf.Sin(Time.time + vertexPos.z),
            //    Mathf.Sin(Time.time + vertexPos.y),
            //    Mathf.Sin(Time.time + vertexPos.x)
            //);
            
            vertices.Add(vertexPos);
        }

        // Here unity automatically assumes that vertices are points and hence will be represented as (x, y, z, 1) in homogenous coordinates
        _mesh.SetVertices(vertices);
        _mesh.SetTriangles(triangles, 0);
        _mesh.RecalculateNormals();

        // Upload mesh data to the GPU
        _mesh.UploadMeshData(false);
    }

    private void Update()
    {
        _mesh.UploadMeshData(false);
    }
}