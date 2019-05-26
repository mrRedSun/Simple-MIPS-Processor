rm -rf obj_dir;
./build.sh;
read -p "Build finished \n Press [Enter] key countinue..."
cd obj_dir/;
./Vtop;
read -p "Press [Enter] key countinue..."
gtkwave Out.vcd --rcvar 'enable_vcd_autosave yes';
cd ..;