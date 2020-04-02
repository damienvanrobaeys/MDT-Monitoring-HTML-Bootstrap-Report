$Date = get-date
$programdata = $env:programdata

$Your_Host = ""

$URL = "http://" + $Your_Host + ":9801/MDTMonitorData/Computers/"
$HTML_Deployment_List = "$programdata\Monitoring_List.htm"

function GetMDTData { 
  $Data = Invoke-RestMethod $URL
  foreach($property in ($Data.content.properties)) 
  { 
		$Percent = $property.PercentComplete.'#text' 		
		$Current_Steps = $property.CurrentStep.'#text'			
		$Total_Steps = $property.TotalSteps.'#text'		
		
		If ($Current_Steps -eq $Total_Steps)
			{
				If ($Percent -eq $null)
					{			
						$Step_Status = "Not started"
					}
				Else
					{
						$Step_Status = "$Current_Steps / $Total_Steps"
					}					
			}
		Else
			{
				$Step_Status = "$Current_Steps / $Total_Steps"			
			}

	
		$Step_Name = $property.StepName		
		If ($Percent -eq 100)
			{
				$Global:StepName = "Deployment finished"
				$Percent_Value = $Percent + "%"				
			}
		Else
			{
				If ($Step_Name -eq "")
					{					
						If ($Percent -gt 0) 					
							{
								$Global:StepName = "Computer restarted"
								$Percent_Value = $Percent + "%"
							}	
						Else							
							{
								$Global:StepName = "Deployment not started"	
								$Percent_Value = "Not started"	
							}

					}
				Else
					{
						$Global:StepName = $property.StepName		
						$Percent_Value = $Percent + "%"					
					}					
			}

		$Deploy_Status = $property.DeploymentStatus.'#text'					
		If (($Percent -eq 100) -and ($Step_Name -eq "") -and ($Deploy_Status -eq 1))
			{
				$Global:StepName = "Running in PE"						
			}			
			
			
		$End_Time = $property.EndTime.'#text' 	
		If ($End_Time -eq $null)
			{
				If ($Percent -eq $null)
					{									
						$EndTime = "Not started"
						$Ellapsed = "Not started"												
					}
				Else
					{
						$EndTime = "Not finished"
						$Ellapsed = "Not finished"					
					}
			}
		Else
			{
				$EndTime = ([datetime]$($property.EndTime.'#text')).ToLocalTime().ToString('HH:mm:ss')  	 
				$Ellapsed = new-timespan -start ([datetime]$($property.starttime.'#text')).ToString('HH:mm:ss') -end ([datetime]$($property.endTime.'#text')).ToString('HH:mm:ss'); 				
			}

    New-Object PSObject -Property @{ 
      "Computer Name" = $($property.Name); 
      "Percent Complete" = $Percent_Value; 	  
      "Step Name" = $StepName;	  	  
      "Step status" = $Step_Status;	  
      Warnings = $($property.Warnings.'#text'); 
      Errors = $($property.Errors.'#text'); 
      "Deployment Status" = $( 
        Switch ($property.DeploymentStatus.'#text') { 
        1 { "Running" } 
        2 { "Failed" } 
        3 { "Success" } 
        4 { "Unresponsive" } 		
        Default { "Unknown" } 
        } 
      ); 	  
      "Date" = $($property.StartTime.'#text').split("T")[0]; 
      "Start time" = ([datetime]$($property.StartTime.'#text')).ToLocalTime().ToString('HH:mm:ss')  
	  "End time" = $EndTime;
      "Ellapsed time" = $Ellapsed;	  	  
    } 
  } 
} 



$AllDatas = GetMDTData | Select Date, "Computer Name", "Percent Complete", "Step Name", Warnings, Errors, "Start time", "End Time", "Ellapsed time", "Step status", "Deployment Status"

If ($AllDatas -eq $null)
	{
		$Alert_Type = "'alert alert-warning alert-dismissible'"
		$Alert_Title = "Oops !!!"		
		$Alert_Message = " There is no deployment in your monitoring history"
		
		$NB_Success = "0"
		$NB_Failed = "0"
		$NB_Runnning = "0"	

		$Search = ""
	}
Else
	{
		$Search = "
		<p> Type something like computer name, deployment status, step name...</p>  

		<input class='form-control' id='myInput' type='text' placeholder='Search..'>
		"  
		
		$NB_Success = ($AllDatas | Where {$_."Deployment Status" -eq "Success"}).count
		$NB_Failed = ($AllDatas | Where {$_."Deployment Status" -eq "Failed"}).count
		$NB_Runnning = ($AllDatas | Where {$_."Deployment Status" -eq "Running"}).count
		$NB_Unresponsive = ($AllDatas | Where {$_."Deployment Status" -eq "Unresponsive"}).count		
		
		If ($NB_Success -eq $null)
			{
				$NB_Success = 0
			}
			
		If ($NB_Failed -eq $null)
			{
				$NB_Failed = 0
			}

		If ($NB_Runnning -eq $null)
			{
				$NB_Runnning = 0
			}

		If ($NB_Unresponsive -eq $null)
			{
				$NB_Unresponsive = 0
			}			
		
		
		If (($NB_Failed -ne 0) -or ($NB_Unresponsive -ne 0))
			{
				$Alert_Type = "'alert alert-danger alert-dismissible'"
				$Alert_Title = "Oops !!!"		
				$Alert_Message = " There is an issue during one of your deployments"			
			}
			
		ElseIf (($NB_Failed -eq 0) -and ($NB_Success -ne 0) -and ($NB_Runnning -eq 0))
			{
				$Alert_Type = "'alert alert-success alert-dismissible'"
				$Alert_Title = "Congrats !!!"		
				$Alert_Message = " All your deployments have been completed with success"
			}	

		ElseIf (($NB_Failed -eq 0) -and ($NB_Success -eq 0) -and ($NB_Runnning -ne 0))
			{
				$Alert_Type = "'alert alert-info alert-dismissible'"
				$Alert_Title = "Info !!!"		
				$Alert_Message = " All your computers are currently being installed"
			}					
	}



$head = '
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/4.1.0/css/bootstrap.min.css">
  <script src="https://ajax.googleapis.com/ajax/libs/jquery/3.3.1/jquery.min.js"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/popper.js/1.14.0/umd/popper.min.js"></script>
  <script src="https://maxcdn.bootstrapcdn.com/bootstrap/4.1.0/js/bootstrap.min.js"></script>
  '
  
$Title = "
<p align='center' > 
<img src="""" width='' height=''/>
<br><br>
<span class='text-primary font-weight-bold lead'>MDT deployment Status</span>
<br><span class=text-success font-italic>This document has been updated on $Date</span></p>
"


$Badges = "
<div id='demo' class='show' align='center'>
<button type='button' class='btn btn-primary'>
	Running <span class='badge badge-light'>$NB_Runnning</span>
</button>
<button type='button' class='btn btn-success'>
	Success <span class='badge badge-light'>$NB_Success</span>
</button>
<button type='button' class='btn btn-danger'>
	Failed <span class='badge badge-light'>$NB_Failed</span>
</button>
<button type='button' class='btn btn-warning'>
	Unresponsive <span class='badge badge-light'>$NB_Unresponsive</span>
</button>
</div>
<br>
"

$Alert = "
<div class=$Alert_Type>
    <button type='button' class='close' data-dismiss='alert'>&times;</button>
	<strong>$Alert_Title</strong>$Alert_Message
</div>
"

$Script = '
<script>
$(document).ready(function(){
  $("#myInput").on("keyup", function() {
    var value = $(this).val().toLowerCase();
    $("#myTable tr").filter(function() {
      $(this).toggle($(this).text().toLowerCase().indexOf(value) > -1)
    });
  });
});
</script>
'


# $html_final = ConvertTo-HTML  -head $head -body "$title<br>$Badges<br>$Alert<br>$Search<br>$MyData<br>$Script"	|

# ForEach {
# if($_ -like "*<td>Success</td>*"){$_ -replace "<tr>", "<tr class=table-success>"}
# elseif($_ -like "*<td>Running</td>*"){$_ -replace "<tr>", "<tr class=table-Primary>"}
# elseif($_ -like "*<td>Failed</td>*"){$_ -replace "<tr>", "<tr class=table-danger>"}
# elseif(($_ -like "*<td>Unresponsive</td>*") -or ($_ -like "*<td>Unknown</td>*")){$_ -replace "<tr>", "<tr class=table-danger>"}
# else{$_}
# } | out-file -encoding ASCII $HTML_Deployment_List 




$MyData = GetMDTData | Select Date, "Computer Name", "Percent Complete", "Step Name", Warnings, Errors, "Start time", "End Time", "Ellapsed time", "Step status", "Deployment Status" | Sort -Property Date |
ConvertTo-HTML `
-head $head -body "$title<br>$Badges<br>$Alert<br>$Search<br>$MyData<br>$Script"	|

ForEach {
if($_ -like "*<td>Failed</td>*"){$_ -replace "<tr>", "<tr class=table-danger>"}
elseif($_ -like "*<td>Success</td>*"){$_ -replace "<tr>", "<tr class=table-success>"}
elseif($_ -like "*<td>Running</td>*"){$_ -replace "<tr>", "<tr class=table-primary>"}
elseif(($_ -like "*<td>Unresponsive</td>*") -or ($_ -like "*<td>Unknown</td>*")){$_ -replace "<tr>", "<tr class=table-warning>"}
else{$_}
} > $HTML_Deployment_List 	


	
$HTML = get-content $HTML_Deployment_List	
$HTML.replace("<table>","<table class=table>").replace("<tr><th>Date",'<thead class="thead-dark"><tr><th>Date').replace('Deployment Status</th></tr>','Deployment Status</th></tr></thead><tbody id="myTable">').replace('</td></tr></table>','</td></tr></tbody></table>') | out-file -encoding ASCII $HTML_Deployment_List
Invoke-Item $HTML_Deployment_List
