//  Copyright (c) 2025-present amlovey
//  
using System.Collections.Generic;
using UnityEngine;

namespace OmniShader.Editor
{
    public class OmniShaderEditorState : ScriptableObject
    {
        public string selectedMenuId = NaviMenus.HOME;
        public bool isMenuExpanded = false;
        public string targetShaderPath;
        public string saveToFileNameFormat = "OmniShader_[FileName].shader";
        public string saveShaderPath = "OmniShader";
        public string[] includedKeywordsInStripper = new string[0];
        public string[] includedPassesInStripper = new string[0];
        public string[] exludedKeywordsInStripper = new string[0];
        public string[] exludedPassesInStripper = new string[0];
        public Rule addRuleControlData = Rule.GetDeault();
        public List<Rule> rulesStoreInPorject = new List<Rule>();
        public string tablePlatformFilter = "All";
        public bool buildSettingEnabled = true;
        public List<OSShader> shaders = null;
        public List<OSMaterial> materials = null;
        public int shaderFilterIndex = 1;
        public string shaderSearchName = string.Empty;

        void OnEnable()
        {
            hideFlags = HideFlags.HideAndDontSave;
        }

        public void SaveBuildSetting()
        {
            OSBuildSetting.Save(rulesStoreInPorject, buildSettingEnabled);
        }
    }
}