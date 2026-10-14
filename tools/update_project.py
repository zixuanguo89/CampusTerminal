from pathlib import Path
root=Path(__file__).resolve().parents[1]
(root/'rtl'/'resource_paths.vh').write_text('`define FONT_MIF "'+(root/'assets'/'font24.mif').as_posix()+'"\n`define VOICE_MIF "'+(root/'assets'/'voice_ima.mif').as_posix()+'"\n',encoding='ascii')
files=list((root/'rtl').glob('*.v'))+list((root/'rtl').glob('*.sv'))
vendor=['IP/video_pll.v','IP/sys_pll.v','hdmi_phy_warpper.v','lane_lvds_10_1.v','hdmi1.4b_transmitter_core/hdmi_1_4b_transmitter_core_wrapper.enc.v','SD/sd_card_top.v','SD/sd_card_cmd.v','SD/sd_card_sec_read_write.v','SD/spi_master.v','include/sdr_as_ram.enc.v','include/sdr_init_ref.enc.v','include/sdr_wrrd.enc.v']
files += [root/'vendor'/v for v in vendor]
def file_xml(path,index,belong='design_1'):
    return f'''<File Path="{path}"><FileInfo><Attr Name="UsedInSyn" Val="true"></Attr><Attr Name="UsedInP&amp;R" Val="true"></Attr><Attr Name="BelongTo" Val="{belong}"></Attr><Attr Name="CompileOrder" Val="{index}"></Attr></FileInfo></File>'''.replace('UsedInP&amp;R','UsedInP&R')
source=''
for category,extension in [('Verilog','.v'),('System_Verilog','.sv')]:
    source+=f'<{category}>\n'+ '\n'.join(file_xml(p.relative_to(root).as_posix(),i+1) for i,p in enumerate(files) if p.suffix==extension)+f'\n</{category}>\n'
source+='<ADC_FILE>'+file_xml('campus_terminal.adc',1,'constraint_1')+'</ADC_FILE>\n<SDC_FILE>'+file_xml('campus_terminal.sdc',2,'constraint_1')+'</SDC_FILE>'
xml=f'''<?xml version="1.0" encoding="UTF-8"?>
<Project Version="3" Minor="2" Path="{root.as_posix()}">
<Project_Created_Time></Project_Created_Time><TD_Version>6.2.178840</TD_Version><Name>campus_terminal</Name>
<HardWare><Family>EG4</Family><Device>EG4S20BG256</Device><Speed></Speed></HardWare>
<Source_Files>{source}</Source_Files>
<FileSets><FileSet Name="design_1" Type="DesignFiles"><Config><Define Name="DEBUG" Val=""></Define></Config></FileSet><FileSet Name="constraint_1" Type="ConstrainFiles"></FileSet></FileSets>
<TOP_MODULE><LABEL>top</LABEL><MODULE>top</MODULE><CREATEINDEX>user</CREATEINDEX></TOP_MODULE>
<Property></Property><Device_Settings></Device_Settings><Configurations></Configurations>
<Runs><Run Name="syn_1" Type="Synthesis" ConstraintSet="constraint_1" Description="" Active="true"><Strategy Name="Default_Synthesis_Strategy"></Strategy><UserParams></UserParams></Run><Run Name="phy_1" Type="PhysicalDesign" ConstraintSet="constraint_1" Description="" SynRun="syn_1" Active="true"><Strategy Name="Default_PhysicalDesign_Strategy"></Strategy><UserParams></UserParams></Run></Runs><Project_Settings></Project_Settings></Project>'''
(root/'campus_terminal.al').write_text(xml,encoding='utf-8')
(root/'sources.txt').write_text('\n'.join(p.relative_to(root).as_posix() for p in files)+'\n',encoding='utf-8')
print('Sources:',len(files))
