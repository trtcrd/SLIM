class Dada2Module extends Module {
  constructor (params) {
    // lien de la doc
    super ("DADA2", "https://github.com/adriantich/SLIM/blob/master/man/sections/DADA2.md");
    this.params = params;
  }
  // I understand that this is an extension of the Module class
  // defined in the module.js file.
  getConfiguration () {
    let conf = super.getConfiguration();

    // retieve the checked value of the radio html for by_lib
    var radios = document.getElementsByName('by_lib');
    for (let i=0 ; i<radios.length ; i++)
    	if (radios[i].checked)
    		conf.params.by_lib = radios[i].value

    var radios = document.getElementsByName('pool');
    for (let i=0 ; i<radios.length ; i++)
        if (radios[i].checked)
        conf.params.pool = radios[i].value

    return conf;
  };
};

module_manager.moduleCreators['DADA2'] = (params) => {
  return new Dada2Module(params);
}
