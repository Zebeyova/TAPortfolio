//  Copyright (c) 2026-present amlovey
// 
using System.Collections.Generic;
using UnityEditor;
using System.Linq;
using UnityEngine;
using System;

namespace OmniShader.Editor
{
    public enum StorageType
    {
        All,
        InAssets,
        InPackages,
    }

    [Serializable]
    public class OSAsset
    {
        public string Name;
        public string Path;
        public string Guid;

        public override string ToString()
        {
            return string.Format("{0}(Name = {1}, Path = {2}; Guid = {3})", this.GetType(), Name, Path, Guid);
        }
    }

    [Serializable]
    public class OSShader : OSAsset
    {
        public Shader GetShaderObject()
        {
            if (Guid.StartsWith("00000000"))
            {
                return Shader.Find(Name);
            }
            
            return AssetDatabase.LoadAssetAtPath<Shader>(Path);
        }
    }

    [Serializable]
    public class OSMaterial : OSAsset
    {
        public string ShaderName;

        public override string ToString()
        {
            return string.Format("{0}(Name = {1}, Path = {2}; Guid = {3}; ShaderName = {4})", this.GetType(), Name, Path, Guid, ShaderName);
        }

        public Material GetMaterialObject()
        {
            return AssetDatabase.LoadAssetAtPath<Material>(Path);
        }
    }

    public class AssetsExplorerHelper
    {
        public static OSMaterial GetMaterial(string guid)
        {
            var osMat = new OSMaterial();
            var path = AssetDatabase.GUIDToAssetPath(guid);
            var mat = AssetDatabase.LoadAssetAtPath<Material>(path);
            osMat.Name = mat.name;
            osMat.Path = path;
            osMat.Guid = guid;

            var shader = mat.shader;
            if (shader == null)
            {
                osMat.ShaderName = null;
                return osMat;
            }

            osMat.ShaderName = mat.shader.name;
            return osMat;
        }

        public static OSShader GetShader(string guid)
        {
            var osShader = new OSShader();
            var path = AssetDatabase.GUIDToAssetPath(guid);
            var shader = AssetDatabase.LoadAssetAtPath<Shader>(path);
            osShader.Name = shader.name;
            osShader.Path = path;
            osShader.Guid = guid;
            return osShader;
        }

        public static OSShader GetShaderByName(string name)
        {
            var shader = Shader.Find(name);
            return new OSShader()
            {
                Name = shader.name,
                Path = AssetDatabase.GetAssetPath(shader),
                Guid = AssetDatabase.AssetPathToGUID(AssetDatabase.GetAssetPath(shader))
            };
        }

        public static List<string> GetAllMaterialGuids(StorageType storageType)
        {
            return AssetDatabase.FindAssets("t:Material")
            .Where(it => IsMatchStorageType(AssetDatabase.GUIDToAssetPath(it), storageType))
            .ToList();
        }

        public static List<string> GetAllShaderNames()
        {
            HashSet<string> names = new HashSet<string>();
            foreach (var guid in AssetDatabase.FindAssets("t:Shader"))
            {
                var shader = AssetDatabase.LoadAssetAtPath<Shader>(AssetDatabase.GUIDToAssetPath(guid));
                names.Add(shader.name);
            }

            var shaders = ShaderUtil.GetAllShaderInfo();
            foreach (var shader in shaders)
            {
                names.Add(shader.name);
            }

            return names.ToList();
        }

        public static List<string> GetAllShaderGuids(StorageType storageType)
        {
            return AssetDatabase.FindAssets("t:Shader")
            .Where(it => IsMatchStorageType(AssetDatabase.GUIDToAssetPath(it), storageType))
            .ToList();
        }

        public static bool IsMatchStorageType(string path, StorageType storageType)
        {
            switch (storageType)
            {
                case StorageType.All:
                    return true;
                case StorageType.InAssets:
                    return path.StartsWith("Assets/");
                case StorageType.InPackages:
                    return path.StartsWith("Packages/");
            }
            return false;
        }
    }
}