class MaintenanceRecordsController < ApplicationController
  def index
    if params[:unassigned]
      @records = MaintenanceRecord.order('created_at DESC').where(machine: nil).paginate(:page => params[:page], :per_page => 50)
      @unassigned_mode = true
    else
      @records = MaintenanceRecord.order('created_at DESC').paginate(:page => params[:page], :per_page => 50)
      @unassigned_records = MaintenanceRecord.order('created_at DESC').where(machine: nil)
    end
    @user = current_user
  end

  def show
    @record = MaintenanceRecord.find(params[:id])
  end

  def new
    @machine = Machine.find(params[:id])
    @record = @machine.maintenance_records.build
    @username = current_user.name
  end

  def create
    MachineMaintenanceService.new.process_from_controller(self, params.require(:maintenance_record).permit(:logfile, :machine_id, :attachments, :maintenance_record))
  end

  def update
    @record = MaintenanceRecord.find(params[:id])

    if @record.update(ok_params)
      add_attachments(params[:attachments])
      redirect_to maintenance_record_path(@record), notice: 'Success!'
    else
      redirect_to maintenance_record_path(@record), error: 'Error!'
    end
  end

  private

  def ok_params
    params.permit(:logfile, :id, :attachments)
  end

  def add_attachments(attachments)
    if attachments
      attachments.each { |attachment|
        @record.attachments.create(attachment: attachment)
      }
    end
  end
end
