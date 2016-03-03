package sapo.route;
import common.db.MoreTypes.HaxeTimestamp;
import common.db.MoreTypes.Privilege;
import haxe.Serializer;
import haxe.Unserializer;
import neko.Web;
import sapo.Context;
import sapo.spod.Survey;
import sapo.spod.User;
import sys.db.Manager;

/**
 * ...
 * @author Caio
 */
using Lambda;
using sapo.route.SummaryRoutes.SummaryTools;

class SummaryRoutes extends AccessControl
{
	//Constante de dia para a query de Histórico (usando %w no STRFTIME)
	static inline var HistoricDay = 5;
	
	//TODO: Pegar params de filtro
	@authorize(PSupervisor, PSuperUser)
	public function doDefault(?args : {?data : String})
	{
		var data = args != null ? args.data : null;
		var wherestr = "";
		if (data != null && data.length > 0)
		{
			var unserializer = new Unserializer(data);
			var users : Array<Int> = unserializer.unserialize();
			
			for (u in users)
			{
				wherestr = wherestr + " AND user_id = " + u;
			}
		}
		
		//Todos os estados atuais da pesquisa por grupo
		//User;group;status - 
		var userCheck = statusGen();
		
		//Map do tipo data; categoria; val que vai para a view (para todos fazer Completas, pendentes e recusadas + os params adicionais (grupo ou usuários)
		var dateVal : Map<String, Map<String, Int>> = new Map();
		
		//TODO: Uncomment this line
		//var resultsQuery = Manager.cnx.request("SELECT s.user_id as user, s.`group` as grupo,STRFTIME('%Y-%m-%d', s.date_finished) as date_end , COUNT(*) as pesqGrupo,  SUM( CASE WHEN checkSupervisor IS NULL THEN 1 ELSE 0 END) as nullSupervisor, SUM( CASE WHEN checkCT IS NULL THEN 1 ELSE 0 END) as nullCT, SUM(CASE WHEN checkSuper IS NULL THEN 1 ELSE 0 END) AS nullSuper FROM Survey s JOIN UpdatedSurvey us ON s.old_survey_id = us.old_survey_id AND s.syncTimestamp = us.syncTimestamp WHERE s.syncTimestamp > "+DateTools.delta(Date.now(), -1000.0*60*60*24*28).getTime()+" GROUP BY s.user_id, s.`group`, date_end ORDER BY s.user_id, s.`group`, date_end").results();
		//TODO: Comment this line
		//Query path: docs/queries/user_summary.sql
		var resultsQuery = Manager.cnx.request("SELECT s.user_id as user, s.`group` as grupo,STRFTIME('%Y-%m-%d', s.date_finished) as date_end , COUNT(*) as pesqGrupo,  SUM( CASE WHEN checkSupervisor IS NULL THEN 1 ELSE 0 END) as nullSupervisor, SUM( CASE WHEN checkCT IS NULL THEN 1 ELSE 0 END) as nullCT, SUM(CASE WHEN checkSuper IS NULL THEN 1 ELSE 0 END) AS nullSuper FROM Survey s JOIN UpdatedSurvey us ON s.old_survey_id = us.old_survey_id AND s.syncTimestamp = us.syncTimestamp WHERE s.syncTimestamp > 1000 "+ wherestr+" GROUP BY s.user_id, s.`group`, date_end ORDER BY s.user_id, s.`group`, date_end").results();
		
		var header = ["Data", "Supervisor", "CT", "Super", "Completas", "Recusadas", "Aceitas"];
		for (r in resultsQuery)
		{
			if (r.date_end == null)
				continue;
			trace(r.date_end);
			var date = r.date_end;
			var curDateHash : Map<String,Int> = new Map();
			if (dateVal.exists(date))
				curDateHash = dateVal.get(date);

			var mode = userCheck.get(r.user).get(r.grupo);
			//trace(userCheck.get(r.user);
				
			switch(mode)
			{
				//Obrigatoriamente todos responderam...n sobe barra, sobem os controles
				case PesqStatus.Aceita:
					var curval = curDateHash.get("Aceitas");
					curDateHash.set("Aceitas", curval + r.pesqGrupo);
				case PesqStatus.Recusada:
					var curval = curDateHash.get("Recusadas");
					curDateHash.set("Recusadas", curval + r.pesqGrupo);
				case PesqStatus.Pendente:
					if (r.nullCT == r.pesqGrupo)
						curDateHash.set("CT", curDateHash.get("CT").getVal() + r.pesqGrupo);
					curDateHash.set("Supervisor",curDateHash.get("Supervisor").getVal() +  r.pesqGrupo);
					curDateHash.set("Super", curDateHash.get("Super").getVal() + r.pesqGrupo);
				case PesqStatus.Completa:
					curDateHash.set("Completas", curDateHash.get("Completas").getVal() + r.pesqGrupo);
					if (r.nullCT == r.pesqGrupo)
						curDateHash.set("CT", curDateHash.get("CT").getVal() + r.pesqGrupo);
					curDateHash.set("Supervisor",curDateHash.get("Supervisor").getVal() +  r.pesqGrupo);
					curDateHash.set("Super", curDateHash.get("Super").getVal() + r.pesqGrupo);
			}
			
			dateVal.set(r.date_end, curDateHash);
		}
		Sys.println(sapo.view.Summary.render(dateVal, header));
	}
	
	@authorize(PSupervisor, PSuperUser)
	public function doHistoric(?args : {data:String})
	{
		var data = args != null ? args.data : null;
		var wherestr = "";
		if (data != null && data.length > 0)
		{
			var unserializer = new Unserializer(data);
			var users : Array<Int> = unserializer.unserialize();
			var i = 0;
			while(i < users.length)
			{
				if (i == 0)
					wherestr = " WHERE user_id = " + users[0];
				else
					wherestr = wherestr + " AND user_id = " + users[i];
				
				i++;
			}
		}
		
		var userCheck = statusGen();
		
		var dateVal : Map<String,Map<String,Int>> = new Map();
		var headers = ['Date', 'Supervisor', 'CT', 'Super', 'Completas', 'Aceitas', 'Recusadas'];
		//docs/queries/User_historic_friday.sql
		var queryDay = Manager.cnx.request("SELECT s.user_id as user, s.`group` as grupo,	DATE(s.date_finished, 'weekday "+HistoricDay+"') as date_end , COUNT(*) as pesqGrupo,  SUM( CASE WHEN checkSupervisor IS NULL THEN 1 ELSE 0 END) as nullSupervisor, SUM( CASE WHEN checkCT IS NULL THEN 1 ELSE 0 END) as nullCT, SUM(CASE WHEN checkSuper IS NULL THEN 1 ELSE 0 END) AS nullSuper FROM Survey s JOIN UpdatedSurvey us 	ON s.old_survey_id = us.old_survey_id AND s.syncTimestamp = us.syncTimestamp "+((wherestr != "") ? wherestr : "WHERE ")+" STRFTIME('%w',s.date_finished) = '"+ HistoricDay+ "' GROUP BY s.user_id, s.`group`, date_end ORDER BY s.user_id, s.`group`, date_end ").results();
		for (q in queryDay)
		{
			if (q.date_end == null)
				break;
			//submap de dateVal	
			var dateMap = new Map<String,Int>();	
			
			if (dateVal.exists(q.date_end))
				dateMap = dateVal.get(q.date_end);
				
			switch(userCheck.get(q.user).get(q.grupo))
			{
				case PesqStatus.Pendente:
					if (q.nullCT == q.pesqGrupo)
						dateMap.set("CT", dateMap.get("CT").getVal() + q.pesqGrupo);
					dateMap.set("Supervisor", dateMap.get("Supervisor").getVal() + q.pesqGrupo);
					dateMap.set("Super", dateMap.get("Super").getVal() + q.pesqGrupo);
				case PesqStatus.Completa:
					dateMap.set("Completas", dateMap.get("Completas").getVal() + q.pesqGrupo);
					dateMap.set("Supervisor", dateMap.get("Supervisor").getVal() + q.pesqGrupo);
					dateMap.set("CT", dateMap.get("CT").getVal() + q.pesqGrupo);
					dateMap.set("Super", dateMap.get("Super").getVal() + q.pesqGrupo);
				case PesqStatus.Aceita, PesqStatus.Recusada:
					continue;
			}
			
			dateVal.set(q.date_end, dateMap);
		}
		
		//SQLITE
		// docs/queries/User_historic.sql
		var queryHistoric = Manager.cnx.request("SELECT s.user_id as user, s.`group` as grupo, DATE(s.date_finished, 'weekday "+HistoricDay+"') as date_end, COUNT(*) as pesqGrupo,  SUM( CASE WHEN checkSupervisor IS NULL THEN 1 ELSE 0 END) as nullSupervisor, SUM( CASE WHEN checkCT IS NULL THEN 1 ELSE 0 END) as nullCT, SUM(CASE WHEN checkSuper IS NULL THEN 1 ELSE 0 END) AS nullSuper FROM Survey s JOIN UpdatedSurvey us ON s.old_survey_id = us.old_survey_id AND s.syncTimestamp = us.syncTimestamp "+((wherestr != "") ? wherestr : "")+" GROUP BY s.user_id, s.`group`, date_end ORDER BY s.user_id, s.`group`, date_end").results();
		for (q in queryHistoric)
		{
			if (q.date_end == null)
				break;
			
			var dateMap = new Map<String,Int>();
			
			if (dateVal.exists(q.date_end))
				dateMap = dateVal.get(q.date_end);
			
			switch(userCheck.get(q.user).get(q.grupo))
			{
				case PesqStatus.Aceita:
					dateMap.set("Aceitas", dateMap.get("Aceitas").getVal() + q.pesqGrupo);
				case PesqStatus.Recusada:
					dateMap.set("Recusadas", dateMap.get("Recusadas").getVal() + q.pesqGrupo);
				case PesqStatus.Pendente, PesqStatus.Completa:
					continue;
			}
			
			dateVal.set(q.date_end, dateMap);
		}
		
		
		Sys.println(sapo.view.Summary.render(dateVal, headers));
	}
	
	@authorize(PSupervisor, PSuperUser)
	public function postUser(?args : {user:User})
	{
		if (args == null)
		{
			Web.redirect("index");
			return;
		}
		 var user = args.user;
		
		var ret = [];
		switch(user.group.privilege)
		{
			case Privilege.PSurveyor:
				ret.push(user.id);
			case Privilege.PSupervisor:
				ret = User.manager.search($supervisor == user, null, false).map(function (v) { return v.id; } ).array();
			default:
				Web.redirect("index");
				return;
		}
		
		var referer = Web.getClientHeader("Referer");
		var serializer = new Serializer();
		serializer.serialize(ret);
		
		Web.redirect(referer + "?data=" + serializer.toString());
		
	}
	
	//Pega todos os status por grupo e um Map de user_id, grupo, e enum de estado
	function statusGen() : Map<Int,Map<Int,PesqStatus>>
	{
		//TODO:Uncomment this line
		//var controlResults = Manager.cnx.request("SELECT s.user_id as user, s.`group` as grupo, COUNT(*) as pesqGrupo, SUM(CASE WHEN (checkSupervisor IS NULL OR checkCT IS NULL OR checkSuper IS NULL) OR ((checkSuperVisor IS NOT NULL AND checkSupervisor != 0 AND checkCT IS NOT NULL AND checkCT != 0 AND checkSuper IS NOT NULL AND checkSuper != 0) AND NOT (checkSupervisor = 1  AND checkCT = 1 AND checkSuper = 1) ) THEN 1 ELSE 0 END) as Completa, SUM(CASE WHEN checkSupervisor = 0 AND checkCT = 0 AND checkSuper = 0 THEN 1 ELSE 0 END) as allFalse, SUM(CASE WHEN checkSupervisor = 0 OR checkCT = 0 OR checkSuper = 0 THEN 1 ELSE 0 END) as hasFalse, SUM(CASE WHEN checkSupervisor = 1 AND checkCT = 1 AND checkSuper = 1 THEN 1 ELSE 0 END) as isTrue, SUM( CASE WHEN checkSupervisor IS NULL THEN 1 ELSE 0 END) as nullSupervisor, SUM( CASE WHEN checkCT IS NULL THEN 1 ELSE 0 END) as nullCT, SUM(CASE WHEN checkSuper IS NULL THEN 1 ELSE 0 END) AS nullSuper FROM Survey s JOIN UpdatedSurvey us ON s.old_survey_id = us.old_survey_id AND s.syncTimestamp = us.syncTimestamp WHERE s.syncTimestamp > "+ DateTools.delta(Date.now(), -1000.0*60*60*24*28).getTime() +" GROUP BY s.user_id, s.`group` ORDER BY s.user_id, s.`group`").results();
		
		//TODO: Comment this line
		//Query path = docs/queries/User_status.sql
		var controlResults = Manager.cnx.request("SELECT s.user_id as user, s.`group` as grupo, COUNT(*) as pesqGrupo, SUM(CASE WHEN (checkSupervisor IS NULL OR checkCT IS NULL OR checkSuper IS NULL) OR ((checkSuperVisor IS NOT NULL AND checkSupervisor != 0 AND checkCT IS NOT NULL AND checkCT != 0 AND checkSuper IS NOT NULL AND checkSuper != 0) AND NOT (checkSupervisor = 1  AND checkCT = 1 AND checkSuper = 1) ) THEN 1 ELSE 0 END) as Completa, SUM(CASE WHEN checkSupervisor = 0 AND checkCT = 0 AND checkSuper = 0 THEN 1 ELSE 0 END) as allFalse, SUM(CASE WHEN checkSupervisor = 0 OR checkCT = 0 OR checkSuper = 0 THEN 1 ELSE 0 END) as hasFalse, SUM(CASE WHEN checkSupervisor = 1 AND checkCT = 1 AND checkSuper = 1 THEN 1 ELSE 0 END) as isTrue, SUM( CASE WHEN checkSupervisor IS NULL THEN 1 ELSE 0 END) as nullSupervisor, SUM( CASE WHEN checkCT IS NULL THEN 1 ELSE 0 END) as nullCT, SUM(CASE WHEN checkSuper IS NULL THEN 1 ELSE 0 END) AS nullSuper FROM Survey s JOIN UpdatedSurvey us ON s.old_survey_id = us.old_survey_id AND s.syncTimestamp = us.syncTimestamp WHERE s.syncTimestamp > 1000 GROUP BY s.user_id, s.`group` ORDER BY s.user_id, s.`group`").results();
		
		var userCheck : Map<Int,Map<Int,PesqStatus>> = new Map();
		userCheck = new Map();
		for (c in controlResults)
		{
			var group : Map<Int, PesqStatus> = new Map();
			if (userCheck.exists(c.user))
				group = userCheck.get(c.user);
			
			var status;
			if (c.allFalse != 0)
				status = PesqStatus.Recusada;
			else if (c.hasFalse != 0)
				status = PesqStatus.Pendente;
			else if (c.isTrue != 0)
				status = PesqStatus.Aceita;
			else
				status = PesqStatus.Completa;
			
			group.set(c.grupo, status);
			userCheck.set(c.user, group);				
		}
		
		return userCheck;
	}
	
	public function new() 
	{
		
	}
	

	
	
}

class SummaryTools
{
	public static function getVal(v : Int) : Int
	{
		return v != null ? v : 0;
	}
}

enum PesqStatus {
	Completa;
	Pendente;
	Recusada;
	Aceita;
}