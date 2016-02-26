package common.spod;
import common.spod.EnumSPOD;
import sys.db.Object;
import sys.db.Types.SBool;
import sys.db.Types.SDateTime;
import sys.db.Types.SEnum;
import sys.db.Types.SFloat;
import sys.db.Types.SId;
import sys.db.Types.SInt;
import sys.db.Types.SNull;
import sys.db.Types.SString;

/**
 * ...
 * @author Caio
 */
class Morador extends Object
{
	public var id : SId;
	
	@:relation(survey_id) public var survey : Survey;
	@:relation(familia_id) public var familia : Familia;
	public var date : SDateTime;
	public var isDeleted : SBool;
	public var isEdited : SInt;
	
	public var nomeMorador : SNull<SString<255>>;
	public var proprioMorador_id : SNull<SBool>;
	public var idade : SNull<SEnum<Idade>>;
	public var genero_id : SNull<SInt>;
	public var grauInstrucao : SNull<SEnum<GrauInstrucao>>;
	@:relation(quemResponde_id) public var quemResponde : SNull<Morador>;
	
	public var situacaoFamiliar : SNull<SEnum<SituacaoFamiliar>>;
	public var atividadeMorador : SNull<SEnum<AtividadeMorador>>;
	public var possuiHabilitacao_id : SNull<SBool>;
	public var portadorNecessidadesEspeciais : SNull<SEnum<PortadorNecessidadesEspeciais>>;
	//TODO
	public var setorAtividadeEmpresaPrivada : SNull<SEnum<SetorAtividadeEmpresaPrivada>;
	public var setorAtividadeEmpresaPublica : SNull<SEnum<SetorAtividadeEmpresaPublica>;
	
	public var motivoSemViagem : SNull<SEnum<MotivoSemViagem>>;
	
	public var syncTimestamp : SFloat;
	public var old_id : SInt;
	public var old_survey_id : SInt;
	
}