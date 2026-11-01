//  Copyright (c) 2025-present amlovey
// 
using System;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;

namespace OmniShader.Editor
{
    [Serializable]
    public class OmniShaderMetaData
    {
        public string workspace_path;
        public string unity_editor_path;
        public List<string> all_shaders;
    }

    public class OmniShaderMetaDataGenerator
    {
        public static void Generate()
        {
            var data = new OmniShaderMetaData();
            data.unity_editor_path = EditorApplication.applicationPath;
            data.workspace_path = Path.GetDirectoryName(Application.dataPath);
            data.all_shaders = AssetsExplorerHelper.GetAllShaderNames();

            var savePath = Path.Combine(data.workspace_path, "Library", "omnishader.json");
            var json = JsonUtility.ToJson(data);
            File.WriteAllText(savePath, json);
        }
    }
}