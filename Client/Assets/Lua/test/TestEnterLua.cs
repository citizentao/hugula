﻿using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;
using XLua;
public class TestEnterLua : MonoBehaviour {
    public string enterLua;
    // Start is called before the first frame update
    public TextAsset luaAsset;
    void Awake () {
        EnterLua.luaenv = new LuaEnv ();
        EnterLua.luaenv.AddLoader ((ref string name) => {
            string name1 = name.Replace ('.', '/');
            string path = Application.dataPath + "/Lua/" + name1 + ".lua";
            var str = File.ReadAllBytes (path);
            return str;
        });

        EnterLua.luaenv.DoString ("require('" + enterLua + "')");
    }

    // Update is called once per frame
    void Update () {

    }
}