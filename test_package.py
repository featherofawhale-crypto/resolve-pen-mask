"""Offline checks for the single-effect native Pen Mask package."""
import hashlib
import json
import re
import unittest
import zipfile

from build import ARCHIVE, ENTRY, LUA_SCRIPT, ROOT, SOURCE, build


class PenMaskPackageTests(unittest.TestCase):
    def test_one_effect_library_entry(self):
        with zipfile.ZipFile(ARCHIVE) as archive:
            self.assertEqual(archive.namelist(), [ENTRY])
            self.assertEqual(archive.read(ENTRY), SOURCE.read_bytes())
            self.assertIsNone(archive.testzip())

    def test_inspector_preset_controls(self):
        source = SOURCE.read_text(encoding="utf-8")
        self.assertIn('LINKS_Name = "形状预设"', source)
        self.assertIn('LINKS_Name = "应用所选预设"', source)
        self.assertEqual(source.count('CCS_AddString = '), 9)
        for label in ("自由绘制", "圆形", "矩形", "圆角矩形", "三角形",
                      "菱形", "五角星", "五边形", "六边形"):
            self.assertIn(f'CCS_AddString = "{label}"', source)
        self.assertIn('BTNCS_Execute = ' + json.dumps(LUA_SCRIPT.read_text(encoding="utf-8"), ensure_ascii=False), source)

    def test_preset_script_targets_clicked_group_and_keeps_animation(self):
        script = LUA_SCRIPT.read_text(encoding="utf-8")
        self.assertIn('root:GetChildrenList()', script)
        self.assertIn('pen.Polyline:GetConnectedOutput():GetTool()', script)
        self.assertIn('curve:SaveSettings()', script)
        self.assertIn('curve:LoadSettings(', script)
        self.assertIn('comp:StartUndo(', script)
        self.assertIn('comp:EndUndo(', script)
        self.assertNotIn('comp:FindTool("MT_Pen")', script)
        self.assertNotIn('os.execute', script)
        self.assertNotIn('io.open', script)

    def test_native_nodes_and_original_preview(self):
        source = SOURCE.read_text(encoding="utf-8")
        self.assertEqual(len(re.findall(r"MainInput1\s*=\s*InstanceInput", source)), 1)
        self.assertEqual(len(re.findall(r"MainOutput1\s*=\s*InstanceOutput", source)), 1)
        nodes = set(re.findall(r"(MT_\w+)\s*=\s*\w+\s*\{", source))
        for node in re.findall(r'SourceOp = "([^"]+)"', source):
            self.assertIn(node, nodes)
        self.assertIn('Mix = Input { Value = 1, }', source)
        self.assertIn('MT_Path = BezierSpline', source)
        self.assertIn('Name = "扩展功能"', source)

    def test_checksum_and_reproducible_archive(self):
        before = ARCHIVE.read_bytes()
        digest = build()
        self.assertEqual(before, ARCHIVE.read_bytes())
        self.assertEqual(digest, hashlib.sha256(before).hexdigest())
        self.assertEqual((ROOT / "SHA256SUMS.txt").read_text().split()[0], digest)


if __name__ == "__main__":
    unittest.main()
